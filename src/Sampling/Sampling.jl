export SamplingPattern

mutable struct SamplingPattern
  shape::Tuple
  redFac::Float64
  patParams
end

include("Simple.jl")
include("Vardens.jl")
include("Lines.jl")
include("PoissonDisk.jl")
include("VDPoissonDisk.jl")
include("CalibrationArea.jl")
include("PointSpreadFunction.jl")


function SamplingPattern(shape::Tuple,redFac::Float64,patFunc::AbstractString;kargs...)

if redFac < 1
  error("Reduction factor redFac must be >= 1")
end

if patFunc == "simple"
  return SamplingPattern(shape,redFac,SimplePatternParams(;kargs...))
elseif patFunc == "vardens"
  return SamplingPattern(shape,redFac,VardensPatternParams(;kargs...))
elseif patFunc == "lines"
  return SamplingPattern(shape,redFac,LinesPatternParams(;kargs...))
elseif patFunc == "poisson"
  return SamplingPattern(shape,redFac,PoissonDiskPatternParams(;kargs...))
elseif patFunc == "vdPoisson"
  return SamplingPattern(shape,redFac,VDPoissonDiskParams(;kargs...))
else
  error("Sample function $(patFunc) not found.")
end

end

function sample_kspace(kspace::AbstractArray,redFac::Float64,patFunc::AbstractString;kargs...)
  sample_kspace(kspace,SamplingPattern(size(kspace),redFac,patFunc;kargs...);kargs...)
end

function sample_kspace(kspace::AbstractArray,pattern::SamplingPattern;kargs...)
  patOut = sample(pattern.shape,pattern.redFac,pattern.patParams;kargs...)
  patOut = sort(patOut)
  return kspace[patOut],patOut
end

function sample_kspace(aqData::AcquisitionData,redFac::Float64,
                       patFunc::AbstractString;rand=true, profiles=false, kargs...)
  numEchoes = aqData.numEchoes
  numCoils = aqData.numCoils
  numSlices = aqData.numSlices
  numNodes = div(length(aqData.kdata), numEchoes*numCoils*numSlices)

  tr = trajectory(aqData.seq)

  if profiles
    numNodes = tr.numSamplingPerProfile * Int(div(tr.numProfiles, redFac))
    kdata_sub = zeros(ComplexF64, numNodes, numEchoes, numCoils, numSlices)
    samplePointer = collect(1:numNodes:length(kdata_sub)-numNodes+1)
  else
    numNodes = Int(div(numNodes, redFac))
    kdata_sub = zeros(ComplexF64, numNodes, numEchoes, numCoils, numSlices)
    samplePointer = collect(1:numNodes:length(kdata_sub)-numNodes+1)
  end

  idx = zeros(Int64, numNodes, numEchoes, numCoils, numSlices)
  seed = 1234

  for i = 1:numEchoes
    samplingShape = (tr.numSamplingPerProfile, tr.numProfiles)
    pattern = SamplingPattern(samplingShape, redFac, patFunc;seed = seed, kargs...)
    patOut = sample(samplingShape,redFac,pattern.patParams;kargs...)
    patOut = sort(patOut)
    for j=1:numCoils, k=1:numSlices
      kdata_sub[:,i,j,k] = kData(aqData,i,j,k)[patOut]
      idx[:,i,j,k] = patOut
    end
    rand && (seed += 1)
  end
  return AcquisitionData(aqData.seq, vec(kdata_sub), aqData.numEchoes, aqData.numCoils, aqData.numSlices, samplePointer, idx)
end

function shuffle_vector(vec::Vector{T};patFunc::AbstractString="poisson",redFac::Float64=one(Float64),kargs...) where T
  shuffle_vector(vec,redFac,patFunc;kargs...)
end

function shuffle_vector(vec::Vector{T},redFac::Float64,patFunc::AbstractString;kargs...) where T
  shuffle_vector(vec,SamplingPattern(size(vec),redFac,patFunc;kargs...);kargs...)
end

function shuffle_vector(vec::Vector{T},pattern::SamplingPattern;kargs...) where T
  patOut = sample(pattern.shape,pattern.redFac,pattern.patParams;kargs...)
  return vec[patOut]
end