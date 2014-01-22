using DictFiles
try rm("/tmp/test") catch end
for i = 1:1000
    p = spawn(`julia stresstesthelper.jl`)
    sleep(10)
    println("killing ...")
    kill(p)
    debug = readall(`h5debug /tmp/test`)
    println("\n i == $i\n $debug")
    if ismatch(r"Error", debug)
        break
    end
end


