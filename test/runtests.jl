println("\nRunning runtests.jl ...")

using FactCheck, DictFiles

shouldtest(f, a) = length(ARGS) == 0 || in(a, ARGS) ? facts(f, a) : nothing
shouldtestcontext(f, a) = length(ARGS) < 2 || a == ARGS[2] ? facts(f, a) : nothing
 
macro throws_pred(ex) FactCheck.throws_pred(ex) end

filename = tempname()
data = [1 2 3 4 5]


shouldtest("Helpers") do
    @fact DictFiles.sortkeys(Any[]) --> Any[]
    @fact DictFiles.sortkeys([3,2,1]) --> [1,2,3]
    @fact DictFiles.sortkeys([3,2,"1"]) --> ["1",2,3]
    @fact DictFiles.sortkeys([3,2,:a,"b"]) --> [2,3,:a,"b"]
end

shouldtest("basic") do
    dictopen(filename) do a
        @fact stat(filename).inode --> not(0)

        a["a"] = (1,2,"a")
        @fact a["a"] --> (1,2,"a")
        a["a"] = "aa"
        @fact a["a"] --> "aa"
        @fact a[] --> Dict("a"=>"aa")
        a["a",1] = 11
        @fact a["a",1] --> 11
        @fact a["a"] --> Dict(1 => 11)
        @fact a[] --> Dict("a" => Dict(1 => 11))
        a["a",2] = 22
        @fact a["a",2] --> 22
        @fact a["a"] --> Dict(1 => 11, 2 => 22)
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22))
        a["b"] = data
        @fact a["b"] --> data
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22), "b" => data)

        delete!(a, "a")
        @fact a[] --> Dict("b" => data)

        delete!(a, "b")
        @fact a[] --> Dict()

        a[] = Dict("a" => Dict(1 => 11, 2 => 22), "b" => data)
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22), "b" => data)
        a["a"] = Dict(1 => 11, 2 => 22)
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22), "b" => data)
        a[:c] = "c"
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22), "b" => data, :c => "c")
    end

    dictopen(filename) do a
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22), "b" => data, :c => "c")
        @fact haskey(a, "a") --> true
        @fact haskey(a, "a", 1) --> true
        @fact haskey(a, "a", :nope) --> false
        @fact haskey(a, "z") --> false

        @fact in("a",keys(a)) --> true
        @fact in("b",keys(a)) --> true
        @fact in(:c,keys(a)) --> true
        @fact in(1,keys(a, "a")) --> true
        @fact in(2,keys(a, "a")) --> true

        a[(1,)] = 1
        @fact a[(1,)] --> 1
        @fact in((1,),keys(a)) --> true

        @fact in(Dict(1 => 11, 2 => 22),values(a)) --> true
        @fact in(11,values(a,"a")) --> true
        @fact in(22,values(a,"a")) --> true
        @fact keys(a,"b") --> Any[]
        @fact values(a,"b") --> Any[]

        @fact get(a, 1, "a") --> Dict(1 => 11, 2 => 22)
        @fact get(a, 1, "z") --> 1

        @fact getkey(a, 1, "a") --> ("a",)
        @fact getkey(a, 1, "z") --> 1
    end

    context("overwrite fields") do
        dictopen(filename,"w") do a
            a[1,1]   = "hi1"
            a[1]     = "hi2"
            a[1,2,1] = "hi3"
            a[1,2]   = "hi4"
            a[1,2,1] = "hi5"
            a[1]     = "hi6"
            a[1,2,1] = "hi7"
            a[1,3]   = "hi8"
        end
    end
end

shouldtest("dictread") do
    filename = tempname()
    a = Dict(:1 => 1, :dict => Dict(:2 => 2, :3 => 3))
    dictwrite(a, filename)
    r = dictread(filename)
    @fact r --> a
    r = dictread(filename, :1)
    @fact r --> 1
    r = dictread(filename, :dict, :2)
    @fact r --> 2
end

shouldtest("Compacting") do
    rm(filename)
    dictopen(filename) do a
        a["a"] = rand(1000,1000)
    end       
    oldsize = filesize(filename)
    dictopen(filename) do a
        a[] = Dict("a" => Dict(1 => 11, 2 => 22), "b" => data, :c => "c")
    end       
    compact(filename)
    dictopen(filename) do a
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22), "b" => data, :c => "c")
    end       
    @fact filesize(filename) < oldsize --> true
end

shouldtest("Error handling") do
    dictopen(filename) do a
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22), "b" => data, :c => "c")
        try
            a["asdf"]
            @fact "no exception" --> "exception"
        catch
            @fact "exception" --> "exception"
        end
        try
            a["a",123]
            @fact "no exception" --> "exception"
        catch
            @fact "exception" --> "exception"
        end
    end
end

shouldtest("Tuple handling") do
    dictopen(filename) do a
        a["a","b",("ID", "param", 0, 0x5bca7c69b794f8ce)] = 123
        @fact a["a","b",("ID", "param", 0, 0x5bca7c69b794f8ce)] --> 123
        @fact a["a"]["b"] --> Dict(("ID", "param", 0, 0x5bca7c69b794f8ce) => 123)
    end
end

shouldtest("mmap") do
    dictopen(filename) do a
        data = rand(2,3)
        setindex!(a, data, "m"; mmap = true)
        m = DictFiles.mmap(a, "m") 
        @fact copy(m) --> data
    end
end

shouldtest("Subviews through DictFile(a, keys)") do
    rm(filename)
    dictopen(filename) do a
        a[] = Dict("a" => Dict(1 => 11, 2 => 22), "b" => data, :c => "c")
        b = DictFile(a, "a")
        @fact keys(b) --> [1,2]
        @fact values(b) --> [11,22]
        b[3] = 33
        @fact b[3] --> 33
        @fact a[] --> Dict("a" => Dict(1 => 11, 2 => 22, 3 => 33), "b" => data, :c => "c")
    end
end

shouldtest("makekey(a, k)") do
    dictopen(filename) do a
        @fact DictFiles.makekey(a, (1,)) --> "/1"
        @fact DictFiles.makekey(a, ('a',)) --> "/'a'"
        @fact DictFiles.makekey(a, ("a",)) --> "/\"a\""
        @fact DictFiles.makekey(a, (1,2)) --> "/1/2"
        @fact DictFiles.makekey(a, (1,2,3,4,5)) --> "/1/2/3/4/5"
        @fact DictFiles.makekey(a, (1,'a',3)) --> "/1/'a'/3"
        @fact DictFiles.makekey(a, (1,'a',"a")) --> "/1/'a'/\"a\""
        @fact DictFiles.makekey(a, ("abc",)) --> "/\"abc\""
        @fact DictFiles.makekey(a, ("abc",(1,2))) --> "/\"abc\"/(1,2)"
        @fact DictFiles.makekey(a, (1.,(1,2))) --> "/1.0/(1,2)"
        @fact DictFiles.makekey(a, (1.f0,(1,2))) --> "/1.0f0/(1,2)"
        @fact DictFiles.makekey(a, (1.f0,(1,2),"asdf",'b')) --> "/1.0f0/(1,2)/\"asdf\"/'b'"
        @fact DictFiles.makekey(a, ([1,2,3],)) --> "/[1,2,3]"
        @fact DictFiles.makekey(a, (1000,)) --> "/1000"
    end
end

try
    rm(filename)
end


shouldtest("stress test") do
    nopen = 10
    nwrites = 200
    types = [Int32,UInt32,Int64,UInt64,Float32,Float64]
    payload() = rand(types[rand(1:length(types))], tuple(1,tuple(map( x -> rand(1:5), 5)...)...)...)

    filename = tempname()

    for iopen = 1:nopen
        data = Array{Any}(nwrites)
        readdata = Array{Any}(nwrites)
        dictopen(filename) do a
            for i = 1:nwrites
                key = map( x -> rand(1:10), 1:rand(1:3))
                data[i] = payload()
                a[key...] = data[i]
                readdata[i] = a[key...]
            end
        end
        for i = 1:length(data) # FIXME remove this
            if readdata[i] != data[i]
                @show i readdata[i] data[i]
            end
        end
        @fact readdata  --> data
    end

    DictFiles.compact(filename)

    rm(filename)
end


shouldtest("parallel") do
    addprocs(3)
    @everywhere using DictFiles
    filename = tempname()
    a = @fetchfrom 2 DictFile(filename)
    a[1] = 10
    @fact (@fetchfrom 2 a[1]) --> 10
    @fact (@fetchfrom 3 a[1]) --> 10
end

shouldtest("blosc") do
    filename = tempname()
    dictopen(filename) do a
        data = rand(2,3)
        a["a"] = blosc(data)
        @fact a["a"] --> data
        data = Dict(1 => rand(2,3), 'c' => "asdf")
        a["a"] = blosc(data)
        @fact a["a"] --> data
    end
end

shouldtest("serialize") do
    filename = tempname()
    dictopen(filename) do a
        data = rand(2,3)
        b = serialized(data)
        a["a"] = b
        @fact a["a"] --> data
    end
end

shouldtest("snapshot") do
    data = rand(10)
    snapshot(data)
    @fact loadsnapshot() --> data
    snapshot("data", data)
    @fact loadsnapshot("data") --> data
    @fact loadsnapshot() --> Dict("data" => data)
    snapshot("data", data, "a", 1)
    @fact loadsnapshot() --> Dict("data" => data, "a" => 1)
    @fact loadsnapshot("a") --> 1
    @fact loadsnapshot("data","a") --> Dict("data" => data, "a" => 1)

end

println("runtests.jl done!")
FactCheck.exitstatus()
