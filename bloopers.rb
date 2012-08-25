
def spiderIds id
    contents = to_c @chash[id]
    contents.each do |cid|
        #puts "contents: #{contents}"
        #puts "id: #{cid}"

        if !@au.index cid
            @rollout_ids.push cid
            #puts "path: #{getpath cid}"
        end
        if @chash[cid]
            #puts "!!!****!!! @chash[id]: #{@chash[cid]}"
            spiderIds cid
        end
    end
end

