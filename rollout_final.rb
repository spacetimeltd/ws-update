require 'csv'
require 'pry'
require 'json'
require 'zip/zip'

@xref = JSON.parse IO.read('xref.json')
@revxref = JSON.parse IO.read('revxref.json')
@ihash = JSON.parse IO.read('ihash.json')
@chash = JSON.parse IO.read('chash.json')
@imageref = JSON.parse IO.read('imageref.json')
@au = JSON.parse IO.read('au.json')

@logfile = File.new "logfile.txt", "w"

load './postproc.rb'
load './helpers.rb'

@idhash = {}

@rollout_ids = []
def spiderIds id

    stack = to_c @chash[id]

    binding.pry

    while !stack.empty?

        cid = stack.delete_at(0)

        if @idhash[cid]
            @idhash[cid] += 1
            next
        else
            @idhash[cid] = 1
        end

        @rollout_ids.push cid

        if @chash[cid]
            stack << to_c(@chash[cid])
            stack.flatten!
        end

    end
end

# find out what ids appear in multiple contents
@mphash = {}
multipath = @ihash.find_all { |z| z[1]['path'] =~ /:/ }
multipath.each do |x|
    alt_locations = x[1]['path'].split ':'
    @mphash[x[0]] = alt_locations
    @logfile << "\"#{x[0]}\"(aka #{@xref[x[0]]})"
    @logfile << " appears in the 'contents' of these pages: #{alt_locations}\n"
end

# then create a hash of these keyed by name instead of id
mpnhash = {}
@ihash.each do |z|
    id = z[0]
    if z[1]['path'] =~ /:/
        mpnhash[z[1]['name']] = z[1]
    end
end

glist = "gettingread inkitchen aroundhouse onmove foryourcomfort1 chrisspec".split

glist.each do |x|
    @rollout_ids = []
    spiderIds x
    puts @rollout_ids.count
    postproc(x+'-without-section')
    @rollout_ids.unshift x
    postproc(x+'-with-section')
end

@logfile.close



#
# paul simon - blew that room away

