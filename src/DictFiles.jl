module DictFiles

export DictFile, dictopen, close, compact
export getindex, get, getkey, setindex!, delete!
@unix ? export mmap : nothing
export haskey, isdict, keys, values

using HDF5, JLD


#####################################################
##   DictFile, dictfile

defaultmode = "r+"

type DictFile
  jld::JLD.JldFile
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
    finalizer(a) = (isempty(a.basekey) ? close(a) : nothing)
    a
  end
  DictFile(fid::JLD.JldFile, basekey::Tuple) = new(fid, basekey)
end

DictFile(filename::String, mode::String = defaultmode, k...) = DictFile(DictFile(filename, mode), k...)
function DictFile(a::DictFile, k...) 
  d = a.jld[makekey(a,k)]
  if !(typeof(d) <: JLD.JldGroup)
    error("DictFile: Try to get proxy DictFile for key $k but that is not a JldGroup")
  end
  DictFile(a.jld, tuple(a.basekey..., k...))
end


function dictopen(f::Function, args...)
    fid = DictFile(args...)
    try
        f(fid)
    finally
        close(fid)
    end
end

#####################################################
##   close

import Base.close
function close(a::DictFile) 
  isempty(a.basekey) ? close(a.jld) : nothing
end


#####################################################
##   getindex, setindex!

function makekey(a::DictFile, k::Tuple)
  function makeliteral(a) 
    buf = IOBuffer()
    show(buf,a)
    return takebuf_string(buf)
  end
  key = "/"*join(tuple(Base.map(makeliteral, a.basekey)..., Base.map(makeliteral, k)...), "/")
  #@show key
  #key
end

function getindex(a::DictFile, k...) 
  key = makekey(a, k)
  if !isempty(k) && !exists(a.jld, key)
    error("DictFile: key $k does not exist")
  end
  if isempty(k)
    k2 = keys(a)
    return Dict(k2, [getindex(a,x) for x in k2])
  elseif typeof(a.jld[key]) <: JLD.JldGroup
    k2 = keys(a, k...)
    d2 = DictFile(a, k...)
    return Dict(k2, map(x->getindex(d2,x), k2))
  else
    return read(a.jld, key) 
  end
end

function setindex!(a::DictFile, v::Dict, k...) 
  if isempty(k)
    map(x->delete!(a,x), keys(a))
    flush(a.jld.plain)
  end
  map(x->setindex!(a, v[x], tuple(k...,x)...), keys(v))
end

function setindex!(a::DictFile, v, k...) 
  if isempty(k)
    error("DictFile: cannot use empty key $k here")
  end

  key = makekey(a, k)
  #@show "in setindex" k key
  for i in 1:length(k)
    subkey = makekey(a, k[1:i])
    if exists(a.jld, subkey) && !(typeof(a.jld[subkey]) <: JLD.JldGroup)
      #@show "deleting subkey" subkey
      HDF5.o_delete(a.jld.plain, subkey)
      flush(a.jld.plain)
      break
    end
  end

  if exists(a.jld, key)
    #@show "in setindex, deleting" key
    HDF5.o_delete(a.jld.plain, key)
    flush(a.jld.plain)
    if exists(a.jld, key)
      error("i thought we deleted this?")
    end
  end

  #@show "in setindex, writing" key
  write(a.jld, key, v)
  flush(a.jld.plain)
end


#####################################################
##   get, getkey

get(a, default, k...)    = haskey(a, k...) ? a[k...] : default
getkey(a, default, k...) = haskey(a, k...) ? k : default

#####################################################
##   delete!

import Base.delete!
function delete!(a::DictFile, k...) 
  key = makekey(a,k)
  #@show "deleting" key
  if exists(a.jld, key)
    HDF5.o_delete(a.jld.plain,key)
    flush(a.jld.plain)
  end
end


#####################################################
##   mmap

@unix ? function mmap(a::DictFile, k...) 
  dataset = a.jld[makekey(a, k)]
  if ismmappable(dataset.plain) 
    return readmmap(dataset.plain) 
  else
    error("DictFile: The dataset for $k does not support mmapping")
  end
end : nothing

#####################################################
##   haskey, keys, values

import Base.haskey
haskey(a::DictFile, k...) = exists(a.jld, makekey(a, k))
function isdict(a::DictFile, k...)
  key = makekey(a,k);
  e = exists(a.jld, key)
  e && typeof(a.jld[key]) <: JLD.JldGroup
end


import Base.keys
parsekey(a) = (a = parse(a); isa(a,QuoteNode) ? Base.unquoted(a) : a)
function sortkeys(a)
    if all(map(x -> isa(x, Real), a))
        ind = sortperm(a)
    else
        ind = sortperm(map(string, a));
    end
    a[ind]
end

function keys(a::DictFile)
  b = isempty(a.basekey) ? a.jld : a.jld[makekey(a,())]
  sortkeys([parsekey(x) for x in names(b)])
end

function keys(a::DictFile, k...)
    key = makekey(a,k)
    if !exists(a.jld, key)
      return {}
    end
    g = a.jld[key]
    if !(isa(g,JLD.JldGroup))
      error("DictFile: keys() or values() was called for key $k, but that is not a HDF5 group")
    end
  sortkeys([parsekey(x) for x in setdiff(names(a.jld[key]), {:id, :file, :plain})])
end

import Base.values
values(a::DictFile, k...) = [a[k..., x] for x in keys(a, k...)]




#####################################################
##   dump

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


#####################################################
##   compact

function compact(filename::String)
  tmpfilename = tempname()
  dictopen(filename) do from
    dictopen(tmpfilename,"w") do to
      function copykey(k)
        if isdict(from, k...)
          map(x->copykey(tuple(k..., x)), keys(from, k...))
          assert(isempty(setdiff(keys(from, k...), keys(to, k...))))
        else
          to[k...] = from[k...]
        end
      end
      [copykey(tuple(x)) for x in keys(from)]
    end
  end
  mv(tmpfilename, filename)
end

end
