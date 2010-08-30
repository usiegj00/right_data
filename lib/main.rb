#!/usr/bin/env ruby
require 'FileSystemItem'
require 'FileSystemTree'
require 'escape'
# require 'unicode'

$KCODE = 'UTF-8'   # only used when encoding is not specified.

# crawler = Index.new
# crawler.crawl

=begin
  #!/usr/bin/ruby
  # find_duplicates.rb
  
  require 'find'
  require 'digest/md5'

  def each_set_of_duplicates(*paths)
    sizes = {}
    Find.find(*paths) do |f|
     (sizes[File.size(f)] ||= []) << f if File.file? f
    end
    sizes.each do |size, files|
      next unless files.size > 1
      md5s = {}
      files.each do |f|
        digest = Digest::MD5.hexdigest(File.read(f))
        (md5s[digest] ||= []) << f
      end
      md5s.each { |sum, files| yield files if files.size > 1 }
    end
  end

  each_set_of_ 
duplicates(*ARGV) do |f|
    puts " 
Duplicates: #{f.join(", ")}"
  end
=end

# http://codeidol.com/other/rubyckbk/System-Administration/Finding-Duplicate-Files/

#!/usr/bin/ruby
# find_duplicates2.rb

require 'find'

module RightData

  BLOCK_SIZE = 1024*8
  IGNORE_FILES = [".DS_Store", ".typeAttributes.dict", "empty-file"]
  def self.ignore_test(f)
    IGNORE_FILES.include?(File.basename(f)) || 
      File.symlink?(f) || 
      (File.size(f) == 0) || # Ignore empty files
      File.basename(f).downcase =~ /\.tmp$/ ||
      File.basename(f).downcase =~ /\.swp$/
  end

  def self.each_set_of_duplicates(*paths, &block)
    sizes = Hash.new {|h, k| h[k] = [] }
    Find.find(*paths) { |f| sizes[File.size(f)] << f if File.file? f }

    sizes.each_pair do |size, files|
    # puts files.inspect
      next unless files.size > 1
      offset = 0
      files = [files]
      while !files.empty? && offset <= size
        files = eliminate_non_duplicates(files, size, offset, &block)
        offset += BLOCK_SIZE
      end
    end
  end

  def self.eliminate_non_duplicates(partition, size, offset)
    possible_duplicates = []
    partition.each do |possible_duplicate_set|
      blocks = Hash.new {|h, k| h[k] = [] }
      possible_duplicate_set.each do |f|
        block = open(f, 'rb') do |file|
          file.seek(offset)
          file.read(BLOCK_SIZE)
        end
        blocks[block || ''] << f
      end
      blocks.each_value do |files|
        if files.size > 1
          if offset+BLOCK_SIZE >= size
            # We know these are duplicates.
            yield files
          else
            # We suspect these are duplicates, but we need to compare
            # more blocks of data.
            possible_duplicates << files
          end
        end
      end
    end
   return possible_duplicates
  end

  def self.index_by_size(*paths)
    sizes = Hash.new {|h, k| h[k] = [] }
    count = 0
    Find.find(*paths) { |f| 
    sizes[File.size(f)] << f if File.file?(f) && !ignore_test(f)
      count += 1
    }
    puts "# Indexed #{count} files."
    sizes
  end

  def self.cache_not_working_on_write(master)
    master_cache = File.join(master,".rightPruneCache")
    if File.exist?(master_cache)
      puts "# Master cache FOUND at #{master_cache}."
      master_index = File.open(master_cache) do |f| 
        YAML::load(f)
      end
    else
      puts "# Master cache not found at #{master_cache}."
      master_index = index_by_size(master)
      puts "# Writing #{master_cache}."
      File.open(master_cache, "w") do |f| 
        YAML.dump(master_index, f)
      end  
      puts "# Wrote #{master_cache}."
    end
    master_index
  end


  def self.cache_serializing_on_write(master)
    master_cache = File.join(master,".rightPruneCache")
    if File.exist?(master_cache)
      puts "# Master cache FOUND at #{master_cache}."
      master_index = File.open(master_cache) do |f| 
        rval = {}
        f.each_line do |l|
          kv = Marshal.load(l)
          rval[kv.first] = kv.last
        end
        rval
      end
    else
      puts "# Master cache not found at #{master_cache}."
      master_index = index_by_size(master)
      puts "# Writing #{master_cache}."
      File.open(master_cache, "w") do |f| 
        master_index.each_pair do |k,v|
          Marshal.dump([k,v], f)
        end
        # f.write(master_index.inspect)
      end  
      puts "# Wrote #{master_cache}."
    end
  end

  def self.get_block(file,offset)
    open(file, 'r') do |f|
      f.seek(offset); f.read(BLOCK_SIZE)
    end
  end

  def self.check_file_in_index(master_index, file_to_check, &block)
    size = File.size(file_to_check)
    return [] if size == 0 # Ignore empty files
    possible_master_dups = master_index[size] || []
      offset = 0
      while !possible_master_dups.empty? && offset <= size
      file_to_check_block = get_block(file_to_check, offset)
        new_possible_master_dups = []
      possible_master_dups.each do |master|
      block = get_block(master,offset)
      if(block == file_to_check_block)
        new_possible_master_dups << master
      end
      end
        possible_master_dups = new_possible_master_dups
        offset += BLOCK_SIZE
      end
    # puts possible_master_dups.inspect
    possible_master_dups
  end

  def self.test
    master = "/Users/jonathan/Dropbox"
    prune  = "/Users/jonathan/Desktop/Old"
    scan_for_prunable(master,prune) { |a,b| puts "#{b.size} : #{a}" }
    # each_set_of_duplicates(prune) 
  end

  def self.scan_for_dup(prunable)
    each_set_of_duplicates(prunable) do |dups|
      puts "# #{Escape.shell_command(dups.shift)}"
      dups.each do |d|
        puts Escape.shell_command(["rm","-rf",d," # dup"])
      end
    end
  end

  # tree = scan_for_prunable(master,prune) { |a,b| puts "#{b.size} : #{a}" }; nil
  def self.scan_for_prunable(master,prune, &block)
    puts "# Ignoring: #{IGNORE_FILES.inspect}"

    master_index = cache_not_working_on_write(master)
    # master_index = index_by_size(master)
    puts "# Found #{master_index.size} unique sizes."

    # dups = check_file_in_index(master_index, "/Users/jonathan/Dropbox/2261093437_fac9fa9008_b.jpg")

    count = 0

    # Recursively compare the files in the filesystem.
    # When a parent node gets a response from all its children
    # that they are dups OR ignorable, that NODE becomes dup_or_ignorable too.
    # This propagates.
    # Then, there is a traversal that grabs all base nodes that are non_dup like:
    # rm -rf /a_path_duped/here     # 14 dups / 9 ignores
    # rm -rf /b_path_duped/way/here # 1 dup
    tree = FileSystemItem.new(prune, :parent => nil)
    # Mark the nodes:
    tree.traverse do |n|
      # Could keep track of empty dirs too...
      if File.directory?(n.path)
        # If empty dir...
        if n.leaf?
          n.ignorable = true
          n.parent.increment_ignorable_children
          next false # Don't bother, no kids
        else
          next true
        end
      end
      count += 1
      if ignore_test(n.path)
        n.ignorable = true
        n.parent.increment_ignorable_children
      else
        # puts n.path
        duplicates = check_file_in_index(master_index, n.path)
        if(!duplicates.empty?) 
          n.duplicates = duplicates
          n.parent.increment_duplicate_children
        end
      end
      true
    end
    puts "# We counted #{count} files. Tree thinks it has #{tree.files}."
    return tree

    if nil
    Find.find(prune) { |f|
      if File.directory? f
        puts "Dir: #{f}"
        prunable_dirs[f] = {}
        next
      end
      # next unless File.file? f
      count += 1
      duplicates = check_file_in_index(master_index, f)
      if(!duplicates.empty?) 
        dups[f] = duplicates
        prunable_files[f] = duplicates
        block.call(f, duplicates) unless block.nil?
      else
        prunable_files[f] = false
      end
    }

    puts "After check. Found #{dups.size} / #{count} dups in master."
    puts "After check. Found #{dups.first.inspect}"
    end

    # puts "Dirs scanned."
    #prunable_dirs.each_pair do |file,prunable|
      #puts "#{'#' if !prunable} #{file}"
    #end

    # puts "Files scanned."
    # prunable_files.keys.sort.each do |file|
      # prunable = prunable_files[file]
      # puts "#{'#' if !prunable} #{file}"
    # end
    # prunable_files
  end

  # This is a weak check! Also does nothing to check one svn in another.
  def self.svn?(path)
    File.directory?(File.join(path, ".svn"))
  end
  def self.git?(path)
    File.directory?(File.join(path, ".git"))
  end
  def self.scan_for_repos(prune, &block)
    tree = FileSystemTree.new(prune, :parent => nil)
    repos = {}
    # Mark the nodes:
    tree.traverse do |n|
      if File.directory?(n.path)
        if svn?(n.path)
          cd_cmd = Escape.shell_command(["cd",n.path])
          status = `#{cd_cmd}; svn status`
          info   = `#{cd_cmd}; svn info`
          repos[n.path] = { :kind => "svn", :status => status, :info => info }
        end
        if git?(n.path)
          cd_cmd = Escape.shell_command(["cd",n.path])
          status = `#{cd_cmd}; git status`
          info   = `#{cd_cmd}; git show`
          repos[n.path] = { :kind => "git", :status => status, :info => info }
        end
        !repos[n.path] # recurse only if we DID NOT find a repo
      end
    end
    repos.keys.sort.each do |k|
      puts "Found #{repos[k][:kind]} repo at: #{k}. \n\tStatus: #{repos[k][:status]}"
    end
    return repos
  end

  # each_set_of_duplicates(dirs) do |f|
  #  puts "Duplicates: #{f.join(", ")}"
  #end

  # With YAML cache:
  # Master cache FOUND at /Users/jonathan/Dropbox/.rightPruneCache.
  # Found 37765 unique sizes.
  # After check. Found 1240 / 1940 dups in master.
end
