using DictFiles, HDF5, JLD

#nopen = 1
#nwrites = 1000
#types = {Int32,Uint32,Int64,Uint64,Float32,Float64,Char}
##payload() = Array(types[rand(1:length(types))], tuple(1,tuple(map((x)->rand(1:5),2:rand(1:5))...)...)...)
#payload() = Array(types[rand(1:length(types))], tuple(1,tuple(map((x)->rand(1:5),5)...)...)...)
#payload() = 1
#
#key2path(key) = join(map(string, key), "/")
#@time for io = 1:nopen
#    jldopen("/tmp/test","w") do a
#        for iwrites = 1:nwrites
#                key = map((x)->rand(1:10),1:rand(1:10))
#                data = payload()
#            try
#                for i = length(key):-1:1
#                    path = key2path(key[1:i])
#                    if exists(a, path)
#                        o_delete(a.plain, path)
#                    end
#                end
#                path = key2path(key)
#                write(a, path, data)
#                readdata = read(a, path)
#                if readdata!=data
#                    @show path typeof(data) readdata[readdata!=data]
#                    error("hm")
#                end
#            catch e
#                @show key typeof(data) size(data)
#                rethrow(e)
#            end
#        end
#    end
#end
#
#exit()
##########
using DictFiles

nopen = 10
nwrites = 2000
types = {Int32,Uint32,Int64,Uint64,Float32,Float64}
payload() = rand(types[rand(1:length(types))], tuple(1,tuple(map((x)->rand(1:5),5)...)...)...)

@time for io = 1:nopen
    #try
        dictopen("/tmp/test") do a
            for iwrites = 1:nwrites
                    key = map((x)->rand(1:10),1:rand(1:10))
                    data = payload()
                try
                    a[key...] = data
                    readdata = a[key...]
                    if readdata!=data
                        @show key typeof(data) readdata data
                        error("hm")
                    end
                catch e
                    @show key typeof(data) size(data)
                    rethrow(e)
                end
            end
        end
    #catch e
    #    dump(e)
    #    if e.msg!="Error closing file"
    #        rethrow(e)
    #    end
    #end
end
DictFiles.compact("/tmp/test")
