using ImageView, GtkReactive, Colors, Images
using PyCall

using BackgroundSegmenter
using ObjectTracker

@pyimport numpy as np
@pyimport skvideo.io as skvio

# minimum area (number of pixels in a time slice) for foreground connected components
const AREA_THRESHOLD = 8
# minimum volume (number of pixels contiguous across time slices)
# for foreground components
const VOLUME_THRESHOLD = 20

sample_data = ["data/lamrey$n.npy" for n in 1:7]

function view(infile, area=AREA_THRESHOLD, volume=VOLUME_THRESHOLD)
    V = load(infile)
    fgbg = filter(V, area, volume);
    for n in 1:length(V)
        if fgbg[n] == 0
            V[n] = 0
        end
    end
    objects = Vector{Object}()
    num_objects = 0
    blob_series = form_blobs(fgbg[2:end, :, :])

    gui = imshow(permutedims(V, [2, 3, 1]))
    for (n, blobs) in enumerate(blob_series)
        num_objects = match!(objects, blobs, num_objects; radius=20)
        for obj in objects
            # if is_transient(obj)
            #     color = RGB(1, 0, 0)
            # else
            if !is_transient(obj)
                color = RGB(0, 0, 1)
                annotate!(gui, AnnotationPoint(obj.centroid[2], obj.centroid[1], z=n+1, shape='.', size=2, color=color))
                annotate!(gui, AnnotationText(obj.centroid[2],
                                            obj.centroid[1]+4,
                                            z=n+1, string(obj.label),
                                            color=color, fontsize=4))
            end
        end
    end
    return
end

function load_video(infile)
    ext = infile[end-3:end]
    if ext == ".npy"
        return np.load(infile)
    elseif ext == ".avi"
        return skvio.vread(infile)[:, :, :, 3] 
    else
        throw(ArgumentError("invalid file type - must be npy or avi"))
    end
end

function filter(V, min_area, min_volume)
    fgbg = zeros(V);
    (t, n, m) = size(V)
    M = MixtureModel(n, m);
    for i in 1:t
        apply!(M, (view(V, i, :, :)), (view(fgbg, i, :, :)));
    end
    if min_area > 0
        for i in 1:t
            c = view(fgbg, i, :, :);
            fgbg[i, :, :] = filter_components(c, min_area);
            fgbg[i, :, :] = morphological_close(c)
        end
    end
    fgbg = filter_components(fgbg, min_volume);
    return fgbg
end