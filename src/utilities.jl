
function nearest_points(y::Number,points::Vector)
    dist = abs.(y .- points)
    return findmin(dist)[2]
end


function min_k(v::Vector,k::Integer)
    if k < length(v)
        return sortperm(v)[1:k]
    else
        return sortperm(v)
    end
end


function decode(state::NGCV_state)
    while !state.stop
        iteration!(state)
    end
    return state.d
end

function decode(y::Vector,r::Vector,dec::NGCV)
    state = NGCV_state(dec,y,r)
    return decode(state)
end


