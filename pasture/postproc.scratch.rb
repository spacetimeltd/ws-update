         #if target['options']
            #code = target['code']
            #opts = target['options']
            #code.gsub! /(^\w*?);/, '\1old;'
            #code.gsub! /\((\w*?)\)/, '(\1old)'
            #code.gsub!(/=(\w*?)(&|$)/, '=\1old\2')
            #opts.gsub! /\((\w*?)\)/, '(\1old)'
            #else
                #target['code'].gsub! /$/, 'old'
        #end

    ##rollout_data_hash.each_pair do |id,record|

    ## these are the udated records including the amy updated
        ## 1. if it's a regular update the old record needs to be pulled
        ##    then added to the rollout data as the original id but with
        ##       new path, new code/options, fixed labels - and made not orderable!
        ## 2. if it's amy updated then only the path and label need to be
        ##    updated
        ##       and only update path if section is being among the updated.

        ##if @au.index id or anything
## check path, it it's indexed by 'name' then it shouldn't need changing
## I don't know if the section will work, why is path keyed to name?

        ## only thing else to do is process the labels, assuming code is
            ## unchanging
        ## the new ids will have to be used to index in the output hash

## the question now is
    ## when to remove the outdated original records
    ## they should be put in a list to update the labels and path and codes

    #binding.pry


    ## I can repeat the @rollout_ids list again to generate the fixed old records
    ## so that they can be added to the rollout after the fixed un-updated records
    ##

   ## the difference being, this time the ids should all be old style, except for
    ## the au members
    ##


    ## -Chop off what we just did and now the old array has to be fixed
    ## -Fix the labels and add the fixed records to the new hash
    ##
    #to_delete = rhash_old.shift(number_of_records)

    #rhash_old.each_index do |index|
        #record = rhash_old[index]
        #rollout_label = ""

        #if(record['label'])
            #labels = record['label'].split
            #labels.each do |label|
                #rollout_label += ((ids_hash[@xref[label]]) ? @xref[label] : label) + " "
            #end
        #end
        #rhash_old[index]['label'] = rollout_label
        #rhash_new[rhash_new.count+1] = rhash_old[index]
    #end

    ##
    ## -Remove problematic data - ie 'code', 'options', etc from obsolete records
    ## -Update path of obsolete records to place them in 'TODELETE' section
    ##

    #to_delete.each_index do |td|
        ## -to update the 'code' and 'options' data I'll have to parse and update
        ## this: see <to_delete-notes.txt>
        #target = to_delete[td]

        #if target['options']
            #code = target['code']
            #opts = target['options']
            #code.gsub! /(^\w*?);/, '\1old;'
            #code.gsub! /\((\w*?)\)/, '(\1old)'
            #code.gsub!(/=(\w*?)(&|$)/, '=\1old\2')
            #opts.gsub! /\((\w*?)\)/, '(\1old)'
            #else
                #target['code'].gsub! /$/, 'old'
        #end

        #target['path'] = 'TODELETE'

        ## then put the processed original data record back into the output array
        #rhash_new[rhash_new.count+1] = target
