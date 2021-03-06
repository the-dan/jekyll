# encoding: UTF-8
require 'csv'

module Jekyll
  class Reader
    attr_reader :site

    def initialize(site)
      @site = site
    end

    # Read Site data from disk and load it into internal data structures.
    #
    # Returns nothing.
    def read
      @site.layouts = LayoutReader.new(site).read
      read_directories
      sort_files!
      @site.data = DataReader.new(site).read(site.config['data_dir'])
      CollectionReader.new(site).read
    end

    # Sorts posts, pages, and static files.
    def sort_files!
      site.posts.sort!
      site.pages.sort_by!(&:name)
      site.static_files.sort_by!(&:relative_path)
    end

    # Recursively traverse directories to find posts, pages and static files
    # that will become part of the site according to the rules in
    # filter_entries.
    #
    # dir - The String relative path of the directory to read. Default: ''.
    #
    # Returns nothing.
    def read_directories(dir = '')
      base = site.in_source_dir(dir)

      dot = Dir.chdir(base) { filter_entries(Dir.entries('.'), base) }
      dot_dirs = dot.select{ |file| File.directory?(@site.in_source_dir(base,file)) }
      dot_files = (dot - dot_dirs)
      if @site.config['convert_all']
        dot_pages = dot_files.select { |file|
          matching_converters = @site.converters.select { |c| 
            c.matches File.extname(@site.in_source_dir(base,file))
          }
          # puts file, matching_converters
          # HACK: dirties possible. skip identity converter assuming it always present in converters list
          matching_converters.count > 1
        }
      else
        dot_pages = dot_files.select{ |file| Utils.has_yaml_header?(@site.in_source_dir(base,file)) }
      end
      
      dot_static_files = dot_files - dot_pages

      retrieve_posts(dir)
      retrieve_dirs(base, dir, dot_dirs)
      retrieve_pages(dir, dot_pages)
      retrieve_static_files(dir, dot_static_files)
    end

    # Retrieves all the posts(posts/drafts) from the given directory
    # and add them to the site and sort them.
    #
    # dir - The String representing the directory to retrieve the posts from.
    #
    # Returns nothing.
    def retrieve_posts(dir)
      site.posts.concat(PostReader.new(site).read(dir))
      site.posts.concat(DraftReader.new(site).read(dir)) if site.show_drafts
    end

    # Recursively traverse directories with the read_directories function.
    #
    # base - The String representing the site's base directory.
    # dir - The String representing the directory to traverse down.
    # dot_dirs - The Array of subdirectories in the dir.
    #
    # Returns nothing.
    def retrieve_dirs(base, dir, dot_dirs)
      dot_dirs.map { |file|
        dir_path = site.in_source_dir(dir,file)
        rel_path = File.join(dir, file)
        @site.reader.read_directories(rel_path) unless @site.dest.sub(/\/$/, '') == dir_path
      }
    end

    # Retrieve all the pages from the current directory,
    # add them to the site and sort them.
    #
    # dir - The String representing the directory retrieve the pages from.
    # dot_pages - The Array of pages in the dir.
    #
    # Returns nothing.
    def retrieve_pages(dir, dot_pages)
      site.pages.concat(PageReader.new(site, dir).read(dot_pages))
    end

    # Retrieve all the static files from the current directory,
    # add them to the site and sort them.
    #
    # dir - The directory retrieve the static files from.
    # dot_static_files - The static files in the dir.
    #
    # Returns nothing.
    def retrieve_static_files(dir, dot_static_files)
      site.static_files.concat(StaticFileReader.new(site, dir).read(dot_static_files))
    end

    # Filter out any files/directories that are hidden or backup files (start
    # with "." or "#" or end with "~"), or contain site content (start with "_"),
    # or are excluded in the site configuration, unless they are web server
    # files such as '.htaccess'.
    #
    # entries - The Array of String file/directory entries to filter.
    # base_directory - The string representing the optional base directory.
    #
    # Returns the Array of filtered entries.
    def filter_entries(entries, base_directory = nil)
      EntryFilter.new(site, base_directory).filter(entries)
    end

    # Read the entries from a particular directory for processing
    #
    # dir - The String representing the relative path of the directory to read.
    # subfolder - The String representing the directory to read.
    #
    # Returns the list of entries to process
    def get_entries(dir, subfolder)
      base = site.in_source_dir(dir, subfolder)
      return [] unless File.exist?(base)
      entries = Dir.chdir(base) { filter_entries(Dir['**/*'], base) }
      entries.delete_if { |e| File.directory?(site.in_source_dir(base, e)) }
    end
  end
end
