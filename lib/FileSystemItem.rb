require 'escape'
module RightData
  class FileSystemItem
    
    attr_reader :relativePath
    attr_reader :parent

    attr_reader :ignore_children
    attr_reader :duplicate_children
    attr_accessor :duplicates
    attr_accessor :ignorable
    
    def initialize path, args
      if args[:parent]
        @relativePath = File.basename(path)
        @parent = args[:parent]
      else
        @relativePath = path
        @parent = nil
      end
      @ignorable = false
      @duplicates = [] # for this node
      @duplicate_children = 0 # counts for children
      @ignore_children    = 0
      self
    end

    def files
      return 0 if leaf? && File.directory?(fullPath)
      return 1 if leaf?
      return children.map {|n| n.files}.inject {|sum, n| sum + n } 
    end
    def ignore_files
      return 0 if leaf? && File.directory?(fullPath)
      return ignorable? ? 1 : 0 if leaf?
      return children.map {|n| n.ignore_files}.inject {|sum, n| sum + n } 
    end
    def duplicate_files
      return 0 if leaf? && File.directory?(fullPath)
      return duplicate? ? 1 : 0 if leaf?
      return children.map {|n| n.duplicate_files}.inject {|sum, n| sum + n } 
    end


    def basename; @relativePath; end
    
    def self.rootItem
      @rootItem ||= self.new '/', :parent => nil
    end
    
    def children
      unless @children
         if File.directory?(fullPath) and File.readable?(fullPath)
           @children = Dir.entries(fullPath).select { |path|
              path != '.' and path != '..'
           }.map { |path|
              FileSystemItem.new path, :parent => self
           }
         else
           @children = nil
         end
      end
      @children
    end
    
    def path; fullPath; end
    def fullPath
      @parent ? File.join(@parent.fullPath, @relativePath) : @relativePath
    end
    
    def childAtIndex n
      children[n]
    end
    
    def numberOfChildren
      children == nil ? -1 : children.size
    end

    def children?; !children.nil? && !children.empty?; end

    def duplicate?
      if leaf?
        !duplicates.empty?
      else # Dup if all ignored / dup children
        ((@ignore_children + @duplicate_children) == numberOfChildren)
      end
    end

    def ignorable?; ignorable; end

    def increment_ignorable_children
      @ignore_children += 1
      update_duplicate_ignorable_status
    end

    def update_duplicate_ignorable_status
      parent.increment_duplicate_children if((@ignore_children + @duplicate_children) == numberOfChildren)
    end

    def increment_duplicate_children
      @duplicate_children += 1
      update_duplicate_ignorable_status
    end

    def leaf?; !children?; end

    def traverse(&block) # Allow proc to decide if we traverse
      if block.call(self) && children?
        children.each { |c| c.traverse(&block) }
      end
    end

    def other_children
      children.size - ignore_children - duplicate_children
    end

    def to_param; to_s; end
    def to_s
      "<Tree :path => #{self.path}, :files => #{self.files}>" 
    end

    def put_for_shell(pre,path,comment)
      if(pre.empty?)
        puts Escape.shell_escape([path, "# #{comment}"])
      else
        puts Escape.shell_escape([pre.split(" "), path, "# #{comment}"].flatten)
      end
    end

    # Inspect the nodes:
    def report(pre="")
      pre += " " if !pre.empty?
      self.traverse do |n|
        # Is this a leaf (e.g. a file)?
        if n.leaf?
          if(File.directory?(n.path))
            # Prune empty dirs!
            put_for_shell(pre,n.path,"Empty dir") # Remove the dups/igns!
            #puts "#{pre}'#{n.path.gsub(/'/,"\\\\'")}' # Empty dir"
          else 
            msg = nil
            msg = " dup(#{n.duplicates.count})" if n.duplicate?
            msg = " ign" if n.ignorable?
            if msg
              put_for_shell(pre,n.path,msg) # Remove the dups/igns!
              # puts "#{pre}'#{n.path.gsub(/'/,"\\\\'")}' #{msg}" # Remove the dups/igns!
            else
              puts "# #{n.path} unique"
            end
          end
          false # Don't traverse deeper!
        else
          if n.duplicate_children + n.ignore_children == n.children.size
            put_for_shell(pre,n.path,"#{n.duplicate_children} dups / #{n.ignore_children} ignores")
            # puts "#{pre}'#{n.path.gsub(/'/,"\\\\'")}' # #{n.duplicate_children} dups / #{n.ignore_children} ignores"
            false # Don't traverse deeper!
          elsif n.children.size == 0
            put_for_shell(pre,n.path," Empty")
            # puts "#{pre}'#{n.path.gsub(/'/,"\\\\'")}' # Empty... "
            false
          else
            puts "# #{n.path} # Not #{n.duplicate_children} dup/ #{n.ignore_children} ign / #{n.other_children} other "
            true
          end
        end
      end
      puts "# #{self.ignore_files} ignores, #{self.duplicate_files} dups of #{self.files} files"
    end
    
  end
end
