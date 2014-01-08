module DictFiles

export DictFile, dictopen, getindex, setindex!, mmap, close, compact, delete!

using HDF5, JLD

defaultmode = "r+"

type DictFile
  fid::JLD.JldFile
  basekey::Tuple
  function DictFile(filename::String, mode::String = defaultmode)
    exists(f) = (s = stat(filename); s.inode!=0)
    if mode == "r" && !exists(filename)
      error("DictFile: file $filename does not exist")
    end

    if mode == "r+" && !exists(filename)
      mode = "w"
    end
    
    a = new(jldopen(filename, mode),()) 
    finalizer(a) = (println("finalizer called"); isempty(a.basekey) ? close(a.fid) : nothing)
    a
  end
  DictFile(fid::JLD.JldFile, basekey::Tuple) = new(fid, basekey)
end

DictFile(filename::String, mode::String = defaultmode, k...) = DictFile(DictFile(filename, mode), k...)
function DictFile(a::DictFile, k...) 
  d = a.fid[makekey(a,k)]
  if !(typeof(d) <: JLD.JldGroup)
    error("DictFile: Try to get proxy DictFile for key $k but that is not a JldGroup")
  end
  DictFile(a.fid, tuple(a.basekey..., k...))
end


function dictopen(f::Function, args...)
    fid = DictFile(args...)
    try
        f(fid)
    finally
        close(fid)
    end
end


function makekey(a::DictFile, k::Tuple)
  r = join(Base.map(string, tuple(a.basekey..., k...)), "/")
  r
end

function getindex(a::DictFile, k...) 
  key = makekey(a, k)
  if isempty(k)
    k2 = keys(a)
    return Dict(k2, [getindex(a,x) for x in k2])
  elseif typeof(a.fid[key]) <: JLD.JldGroup
    k2 = keys(a, k...)
    d2 = DictFile(a, k...)
    return Dict(k2, map(x->getindex(d2,x), k2))
  else
    return read(a.fid, key) 
  end
end
setindex!(a::DictFile, v::Dict, k...) = map(x->setindex!(a, v[x], tuple(k...,x)...), keys(v))

function setindex!(a::DictFile, v, k...) 
  if isempty(k)
    error("DictFile: cannot use empty key $k here")
  end

  key = makekey(a, k)
  for i in 1:length(k)-1
    subkey = makekey(a, k[1:i])
    if exists(a.fid,subkey) && !(typeof(a.fid[subkey]) <: JLD.JldGroup)
      HDF5.o_delete(a.fid.plain, subkey)
    end
  end

  if exists(a.fid, key)
    HDF5.o_delete(a.fid.plain, key)
  end

  write(a.fid, key, v)
end

import Base.delete!
delete!(a::DictFile, k...) = (key = makekey(a,k); exists(a.fid, key) ? HDF5.o_delete(a.fid.plain,key) : nothing)

function mmap(a::DictFile, k...) 
  dataset = a.fid[makekey(a, k)]
  if ismmappable(dataset) 
    return readmmap(dataset) 
  else
    error("DictFile: The dataset for $k does not support mmapping")
  end
end
import Base.keys
keys(a::DictFile) = names(a.fid)
keys(a::DictFile, k...) = setdiff(names(a.fid[makekey(a, k)]), {:id, :file, :plain})

import Base.close
close(a::DictFile) = close(a.fid)

import Base.dump
dump(a::DictFile) = dump(STDOUT, a)
function dump(io::IO, a::DictFile, maxdepth::Int = typemax(Int))
  function printkey(k, maxdepth, indent = 0)
    #@show k makekey(k) indent keys(a, k...)
    subkeys = sort(keys(a, k...))
    println(repeat("  ",indent), k[end], length(subkeys)>0 ? ":" : "")
    if indent<maxdepth
      Base.map(x-> printkey(tuple(k...,x), maxdepth, indent+1), subkeys)
    end
  end
  Base.map(x->printkey(tuple(x), maxdepth), sort(keys(a)))
end

function compact(filename::String)
  tmpfilename = tempname()
  dictopen(tmpfilename,"w") do to
    dictopen(filename) do from
      function copykey(k)
        d = from.fid[makekey(from, k)]
        if typeof(d) <: JLD.JldGroup
          map(x->copykey(tuple(k..., x)), keys(from, k...))
          assert(isempty(setdiff(keys(from, k...), keys(to, k...))))
        else
          to[k...] = from[k...]
        end
      end
      [copykey(tuple(x)) for x in keys(from)]
    end
    close(to)
    mv(tmpfilename, filename)
  end
end

end
