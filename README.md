# DictFiles 
[![Build Status](http://pkg.julialang.org/badges/DictFiles_0.4.svg)](http://pkg.julialang.org/?pkg=DictFiles&ver=0.4)
[![Build Status](http://pkg.julialang.org/badges/DictFiles_0.5.svg)](http://pkg.julialang.org/?pkg=DictFiles&ver=0.5)

`DictFiles` provides an easy to use abstraction over the excellent `JLD`
and `HDF5` packages by Tim Holy. A `DictFile` is a standard `JLD` file which behaves similar to nested `Dict`'s:

```jl
using DictFiles
dictopen("/tmp/test") do a
    a["key1"] = [1 2 3]
    a["key1"]            # == [1 2 3]
	a[]                  # == Dict("key1"=>[1 2 3])

    a["key2",1] = "One"
    a["key2","two"] = 2
    a["key2"]            # == Dict(1 => "One", "two" => 2)
    a["key2", 1]         # == "One"

    a[:mykey] = Dict("item" => 2.2)
    a[:mykey,"item"]    # == 2.2
end
```

It provides additional features for memory-mapping individual entries and compacting of the file to reclaim space lost through deletions / updates.

## Installation

Simply add the package using Julia's package manager once:

```jl
Pkg.add("DictFiles")
```

You also need the master branch of `HDF5.jl`:

```jl
Pkg.checkout("HDF5")
```

Then include it where you need it:

```jl
using DictFiles
```

## Documentation

`DictFile`s behave like nested `Dict`s. The primary way to assess a `DictFile df` is using `df[keys...] = value` and `df[keys...]`, where `keys` is a tuple of primitive types, i.e. strings, chars, numbers, tuples, small arrays.

### DictFile, dictopen, close

```jl
a = DictFile("/tmp/test")
# do something with a
close(a)
```

A better way do to this, in case an error occurs, is:

```jl
dictopen("/tmp/test") do a
    # do something with a
end
```

Like `open`, both methods take a mode parameter, with the default being `r+`, with the added behavior for `r+` that the file is created when it does not exist yet.

### dictread, dictwrite

To read the entire contents of a file:

```jl
r = dictread(filename)
```

To overwrite the entire contents of a dictfile with a `Dict`:

```jl
dictwrite(somedict, filename)
```

### Setting and getting, browsing, deleting

```jl
dictopen("/tmp/test") do a
    a["mykey"] = 1
    a["mykey"]                #  returns 1
 
    # following the metaphor of nested Dict's:
    a[] = Dict("mykey" => 1, "another key" => Dict("a"=>"A", :b =>"B", 1=>'c'))
    a[]                       # gets the entire contents as one Dict()

    a["another key", :b]      #  "B"
    a["another key"]          #  Dict("a"=>"A", :b =>"B", 1=>'c')

    keys(a)                   #  Dict("another key","mykey") 
    keys(a,"another key")     #  Dict("a",1,:b) 
    values(a)                 #  [Dict(:b=>"B",1=>'c',"a"=>"A"),1] 
    values(a,"another key")   #  Dict("A",'c',"B") 
    haskey(a,"mykey") ? println("has key!") : nothing

    # note that the default parameter for get comes second! 
    get(a, "default", "mykey")   #  1 
    delete!(a, "mykey")
    get(a, "default", "mykey")   #  "default"
end
```

In case you have a very nested data structure in your file and want to only work on a part of it:

```jl
dictopen("/tmp/test") do a 
    a[] = Dict("some"=>1, "nested data" => Dict("a" => 1, "b" => 2))
    b = DictFile(a, "nested data")   #  e.g., you can pass b to other functions
    keys(b)                          #  {"a","b"] 
    b["c"] = 3 
    a[]                              #  Dict("some"=>1, 
                                     #  "nested data" => Dict("a" => 1, "b" => 2, "c" => 3))
end
```

### Compacting

When fields get overwritten or explicitly deleted, HDF5 appends the new data to the file und unlinks the old data. The space of the original data is not recovered. For this, you can compact the file from time to time. This copies all data to a temporary file and replaces the original on success.

```jl
    DictFiles.compact("/tmp/test")
```


## Contibuting

I'd be very grateful for bug reports und feature suggestions - please file an issue!
