require 'fileutils'
require 'erb'
require 'rubygems'
require 'RedCloth'

class Textile2Html

  DEFAULT_OPTIONS = {
    :layout => File.expand_path("./textile2html_layout.html.erb", File.dirname(__FILE__)),
    :src_dir => File.expand_path("."),
    :dest_dir => File.expand_path("."),
    :noop => false,
    :verbose => false,
  }

  attr_reader :options
  def initialize
    @options = DEFAULT_OPTIONS.dup
  end

  def binding_for_yield
    binding
  end

  def pickup_headers(body)
    links = []
    result = body.gsub(/(<h[1-6]>)(.*?)<\/h[1-6]>/) do |*args|
      # puts "args: #{args.inspect}"
      tag, desc = $1, $2
      depth = tag.gsub(/\D/, '').to_i
      links << [depth, desc]
      "<h#{depth}><a name=\"#{desc}\">#{desc}</a></h#{depth}>"
    end
    return result, links
  end

  def build_page_outlines(links)
    src = links.map{|(depth, desc)| "#" * depth << ' "' << desc << '":#' << desc }.join("\n")
    RedCloth.new(src).to_html
  end

  EXTENSIONS = {
    :textile => %w[textile],
    :html_template => %w[html.erb],
    :css_template => %w[css.erb],
    :text => %w[html css],
    :image => %w[png jpg gif icon],
  }
  EXTENSION_PATTERNS = EXTENSIONS.inject({}) do |dest, (t, exts)|
    key = Regexp.union( exts.map{|ext| /\.#{Regexp.escape(ext)}\Z/i} )
    dest[key] = t
    dest
  end

  def execute
    @layout_erb = ERB.new(File.read(options[:layout]))
    @src_dir = File.expand_path(options[:src_dir])
    src_files = Dir["#{@src_dir}/**/*.*"]
    src_files.each do |src_file|
      EXTENSION_PATTERNS.each do |pattern, ext_type|
        if src_file =~ pattern
          @src_path = src_file
          @rel_path = src_file.sub(/^#{Regexp.escape(@src_dir)}\//, '')
          @rel_path_depth = @rel_path.split(/\//).length - 1
          puts "processing: #{src_file}"
          send("process_#{ext_type}", src_file)
          break
        end
      end
    end
  end

  def process_textile(src_file)
    src = ERB.new(File.read(src_file)).result
    html_body = RedCloth.new(src).to_html
    html_body, links = pickup_headers(html_body)
    b = binding_for_yield do|*args|
      arg = args.first
      case arg
      when nil then html_body
      when :page_outline then build_page_outlines(links)
      else
        nil
      end
    end
    html = @layout_erb.result(b)
    write_text(src_file, html, [/\.textile$/, '.html'])
  end

  def process_html_template(src_file)
    html_body = ERB.new(File.read(src_file)).result
    b = binding_for_yield{|*args| html_body}
    html = @layout_erb.result(b)
    write_text(src_file, html, [/\.erb$/i, ''])
  end

  def process_css_template(src_file)
    body = ERB.new(File.read(src_file)).result
    write_text(src_file, body, [/\.erb$/i, ''])
  end

  def process_text(src_file)
    copy(src_file)
  end

  def process_image(src_file)
    copy(src_file)
  end

  private

  def copy(src_file, path_sub_args = [])
    dest_path = dest_path(src_file, path_sub_args)
    dest_dir = File.dirname(dest_path)
    FileUtils.mkdir_p(dest_dir)
    FileUtils.cp(src_file, dest_path)
  end

  def write_text(src_file, text, path_sub_args)
    dest_path = dest_path(src_file, path_sub_args)
    dest_dir = File.dirname(dest_path)
    FileUtils.mkdir_p(dest_dir)
    File.open(dest_path, "w"){|f| f.puts(text)}
  end

  def dest_path(src_file, path_sub_args)
    dest_rel_path = path_sub_args.empty? ?
      @rel_path :
      @rel_path.sub(*path_sub_args)
    File.expand_path(dest_rel_path, options[:dest_dir])
  end


end
