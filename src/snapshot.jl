export snapshot, loadsnapshot

# macro snapshot(a...)
#     quote
        # dictopen("/tmp/snapshot.dictfile") do df
        #     for i = 1:length(a)
        #         #@show a[1] $a[i]
        #         df[string(a[i])] = [i]
        #     end
        # end
    # end
# end

function snapshot(a...)
    dictopen("/tmp/snapshot.dictfile","w") do df
        if length(a) == 1
            a = (:Dictfile_snapshot, a[1])
        end
        for i = 1:2:length(a)
            df[a[i]] = a[i+1]
        end
    end
end

loadsnapshot(a...) = dictopen("/tmp/snapshot.dictfile","r") do df
    if length(a) == 0
        r = df[]
        if collect(keys(r)) == [:Dictfile_snapshot]
            return df[:Dictfile_snapshot]
        end
        r
    else
        if length(a) == 1
            df[a[1]]
        else
            Dict(zip(a, [df[x] for x in a]))
        end
    end
end
 
