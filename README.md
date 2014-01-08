[[Build Status][]https://travis-ci.org/rened/DictFiles.jl.png][]

# DictFiles

`DictFiles` provides an easy to use abstraction over the excellent `JLD`
and `HDF5` packages by Tim Holy. A `DictFile` is a standard `JLD` file which behaves similar to nested `Dict`'s:

    using DictFiles
    dictopen("/tmp/test") do a
        a["key1"]       = "Test"
        a["key2"]       = [1 2 3]
        a["key3",1]     = "One"
        a["key3","two"] = "Two!"
        a[4]            = {"last"=>1, "item"=>2.2}

        # a now behaves like this:
        # {"key1" => "Test",
        #  "key2" => [1 2 3],
        #  "key3" => { 1    => "One",
        #              "two" => "Two!"},
        #  4      => { "last" => 1,
        #              "item" => 2.2}
        #  }

        a["key2"]      # == [1 2 3]
        a["key3"]      # == {1 => "One", "two" => "Two!"}
        a[4,"item"]    # == 2.2
    end

It provides additional features for memory-mapping individual entries and compacting of the file to reclaim space lost through deletions / updates.

## Installation

Simply add the package using Julia's package manager once:

    Pkg.add("DictFiles")

Then include it where you need it:

    using DataFiles

## Documentation

`DictFile`s behave like nested `Dict`s. The primary way to assess a `DictFile df` is using `df[keys...] = value` and `df[keys...]`.

### DictFile, dictopen, close

    a = DictFile("/tmp/test")
    # do something with a
    close(a)

A better way do to this, in case an error occurs, is:

    dictopen("/tmp/test") do a
        # do something with a
    end

Like `open`, both methods take a mode parameter, with the default being `r+`, with the added behavior for `r+` that the file is created when it does not exist yet.

### Setting and getting, browsing, deleting

    dictopen("/tmp/test") do a
        a["mykey"] = 1
        a["mykey"]                #  returns 1
     
        # following the metaphor of nested Dict's:
        a[] = {"mykey" => 1, "another key" => {"a"=>"A", :b =>"B", 1=>'c'}}
        a[]                       # gets the entire contents as one Dict()

        a["another key", :b]      #  "B"
        a["another key"]          #  {"a"=>"A", :b =>"B", 1=>'c'}

        keys(a)                   #  {"another key","mykey"} 
        keys(a,"another key")     #  {"a",1,:b} 
        values(a)                 #  {{:b=>"B",1=>'c',"a"=>"A"},1} 
        values(a,"another key")   #  {"A",'c',"B"} 
        haskey(a,"mykey") ? println("has key!") : nothing

        # note that the default parameter for get comes second! 
        get(a, "default", "mykey")   #  1 
        delete!(a, "mykey")
        get(a, "default", "mykey")   #  "default"
    end

In case you have a very nested data structure in your file and want to only work on a part of it:

    dictopen("/tmp/test") do a 
        a[] = {"some"=>1, "nested data" => {"a" => 1, "b" => 2}}
        b = DictFile(a, "nested data")   #  e.g., you can pass b to other functions
        keys(b)                          #  {"a","b"} 
        b["c"] = 3 
        a[]                              #  {"some"=>1, 
                                         #  "nested data" => {"a" => 1, "b" => 2, "c" => 3}}
    end

### Compacting

When fields get overwritten or explicitly deleted, HDF5 appends the new data to the file und unlinks the old data. The space of the original data is not recovered. For this, you can compact the file from time to time. This copies all data to a temporary file and replaces the original on success.

    DictFiles.compact("/tmp/test")

### Memory mapping

Especially when only parts of large arrays are required, or the array is to large to fit in memory, memory mapping is king.

    dictopen("/tmp/test") do a
        a["mydata"] = rand(100,1000)
        m = mmap(a, "mydata")  # m is of type Array{Float64}, size 100 x 1000
    end

## Contibuting

I'd be very grateful for bug reports und feature suggestions - please file an issue!

  [[Build Status][]https://travis-ci.org/rened/DictFiles.jl.png]: https://travis-ci.org/rened/DictFiles.jl
