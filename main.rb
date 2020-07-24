require "scrub_rb"
require "open3"

class DevGitStat
  #constructor
  def initialize(args)
    @data = nil
    @files = files
    @sub_line = args.fetch(:sub_line)
    @author = args.fetch(:author)
    @authors = Hash.new { |hash, key| hash[key] = [] }
    @lines = nil
    @directory = File.expand_path(args.fetch(:repository))
    @git_dir = File.join(@directory, ".git")

    author_parse
  end
  #Author parse can find all the files that user working with
  def author_parse
    begin
    data = (execute ("git #{git_directory_params} log --raw")).to_s.split("\n\n")
    rescue IOError
      abort "#{@directory} is not a git directory :("
    end
    elements = data.size / 3
    author_name_iter = 0
    file_name_iter = 2

    elements.times do |i|

      #parse author names
      author_name = /Author: [\w ]+ </.match(data[author_name_iter])
      author_name = ((author_name.to_s.delete('<'))[8..-1]).chomp(' ')
      @authors["#{author_name}"]
      #parse file names
      filename = (data[file_name_iter]).split("\n")

      #save
      filename.each do |line|
        @authors["#{author_name}"] << Hash["#{(/[.\w]+$/.match(line))}", []] unless (@authors["#{author_name}"])
                                                                                        .include?(Hash["#{(/[.\w]+$/
                                                                                                               .match(line))}", []])
        # @authors["#{author_name}"] << Hash.new["#{(/[.\w]+$/.match(line))}", %w[]]

      end

      #iteration
      author_name_iter += 3
      file_name_iter += 3
    end
    @authors
  end
  #blame parser can write all the git blame data to a hash with filename key
  def blame_parse
    return unless @authors
    abort 'Not exist user :( ' unless @authors.keys.include?(@author)

    blame_data = Hash.new

    @authors[@author].each do |file|
      blame_data["#{(file.keys.to_s)[2..-3]}"] = (execute "git #{git_directory_params} blame #{file.keys.to_s[2..-3]}").to_s
    end
    blame_data
  end
  #grep parse can find all the lines with sublines and write to a hash wit hfile name key
  def grep_parse
    return unless @sub_line
    begin
      data_from_file = (execute "git #{git_directory_params} grep -n '#{@sub_line}'").to_s
      files_with_sl = Hash.new { |hash, key| hash[key] = [] }

      data_from_file.split("\n").each do |line|
        files_with_sl["#{/^[\w.]+/.match(line)}"] << ((/:[0-9]+:/.match(line)).to_s)[1..-2]
      end

      files_with_sl
    rescue IOError
      abort "Not found any sublines like a #{@sub_line} :("
    end
  end
  #main parser can find all user`s lines with subline
  def search_line_each_author
    blame_data = blame_parse
    grep_data = grep_parse

    (grep_data.keys.to_ary).each do |file|
      grep_data[file].each do |num_line|
        reg = "#{@author} +[-0-9]+ +[:0-9]+ +[+0-9]+ +#{num_line}[^0-9]"
        if (Regexp.new(reg) =~ (blame_data[file]))
          @authors["#{@author}"].each do |element|

            if element.include?(file)
              element["#{file}"] << num_line

              break
            end

          end
        end
      end
    end

    printer
  end

  private
  #print information
  def printer
    any_lines = false
    puts '-' * 80
    puts "User: #{@author}   SubLine: #{@sub_line}"
    @authors[@author].each do |element|
      if element[element.keys.to_s[2..-3]].size > 0
        puts element
        any_lines = true
      end
    end
    puts 'This user has no lines with this subline :(' unless any_lines
    puts '-' * 80
  end
  #gives all files in the directory
  def files
    return execute("ls #{@directory}")
  end

#Execute command from terminal
  def execute(command)
    result = run_no_timeout(command)
    if result.success?
      return result
    else
      raise IOError, cmd_error_message(command, result.data)
    end
  end

  def cmd_error_message(command, message)
    "Could not run '#{command}' => #{message}"
  end

  def run_no_timeout(command)
    out, err, status = Open3.capture3(command)
    ok = status.success?
    output = ok ? out : err
    Result.new(output.scrub.strip, ok)

  end

  def git_directory_params
    "--git-dir='#{@git_dir}' --work-tree='#{@directory}'"
  end

end

#save information from terminal
class Result < Struct.new(:data, :success)
  def to_s
    data;
  end

  def success?
    success;
  end
end

#start script
path = ARGV[0] #you also can enter path to directory from command line, just use arguments
author = ARGV[1]
sub_line = ARGV[2]

unless (path)
  puts 'Enter path to a git directory, if devGitStat.rb run into git directory - enter empty line:'
  path = STDIN.gets.chomp
  unless (path)
    path = "."
  end
end

unless author
  puts 'Enter user`s name:'
  author = STDIN.gets.chomp
end

unless sub_line
  puts 'Enter sublune:'
  sub_line = STDIN.gets.chomp
end


parser = DevGitStat.new({
                            repository: path,
                            author: author,
                            sub_line: sub_line
                        })


parser.search_line_each_author

