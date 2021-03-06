require 'webrick/httputils'

class SeleniumController < ActionController::Base
  include SeleniumOnRails::FixtureLoader
  include SeleniumOnRails::Renderer

  def initialize
    @result_dir = SeleniumOnRailsConfig.get(:result_dir)
  end

  def setup
    unless params.has_key? :keep_session
			previous_testname = Rails.cache.read('selenium.previous_testname')
      Rails.cache.clear
			Rails.cache.write('selenium.previous_testname', previous_testname)
      reset_session #  IS THIS WORKING!  NO THINK SO
      @session_wiped = true
    end
    @cleared_tables = clear_tables params[:clear_tables].to_s
    @loaded_fixtures = load_fixtures params[:fixtures].to_s
    render :file => view_path('setup.rhtml'), :layout => layout_path
  end

  def test_file
    params[:testname] = '' if params[:testname].to_s == 'TestSuite.html'
    filename = File.join selenium_tests_path, params[:testname]
    if File.directory? filename
			Rails.cache.delete('selenium.previous_testname')
      @suite_path = filename
      render :file => view_path('test_suite.rhtml'), :layout => layout_path
    elsif File.readable? filename
      previous_testname = Rails.cache.read('selenium.previous_testname')
      if previous_testname
        logger.info "Taking Final Screenshot for: #{previous_testname}"
      take_screenshot(screenshot_path("final/#{previous_testname}.png"))
    end
      render_test_case filename
      Rails.cache.write('selenium.previous_testname', params[:testname])
    else
      if File.directory? selenium_tests_path
        render :text => 'Not found', :status => 404
      else
        render :text => "Did not find the Selenium tests path (#{selenium_tests_path}). Run script/generate selenium", :status => 404
      end
    end
  end

  def support_file
    if params[:filename].empty?
      redirect_to :filename => 'TestRunner.html', :test => 'tests'
      return
    end

    filename = File.join selenium_path, params[:filename]
    if File.file? filename
      type = WEBrick::HTTPUtils::DefaultMimeTypes[$1.downcase] if filename =~ /\.(\w+)$/
      type ||= 'text/html'
      type = 'text/javascript' if filename =~ /\.js$/
      send_file filename, :type => type, :disposition => 'inline', :stream => false
    else
      render :text => 'Not found', :status => 404
    end
  end

  def screenshot
		result = take_screenshot(params[:filename])
    render :text=>"Screenshot Taken, result: #{result}"
  end

	private
	def screenshot_path(filename)
	  case request.user_agent
	    when /(gecko)/i
	      browser = :gecko
	    when /(webkit)/i
	      browser = :webkit
	    when /msie\s+7\.\d+/i
	      browser = :ie7
	    when /msie/i
	      browser = :ie
	    else
	      browser = :unknown
	  end
	  "#{ENV['CC_BUILD_ARTIFACTS']}/screenshots/#{browser}/#{filename}"
	end

	def take_screenshot(filename)
	  begin
      path = File.dirname(filename)
      FileUtils::mkdir_p(path)
      display = SeleniumOnRailsConfig.get(:xvfb_display, ':555')
      cmd = "/usr/bin/import -display #{display} -window root #{filename}"
      logger.info "Taking Screenshot with: #{cmd}"
      p "Taking Screenshot with: #{cmd}"
      result = system(cmd)

      smallfilename = File.dirname(filename)+'/thumbnails'
      FileUtils::mkdir_p(smallfilename)
      smallfilename = smallfilename + '/' + File.basename(filename)
      resizecmd = "/usr/bin/convert #{filename} -resize 20% #{smallfilename}"
      logger.info "Reducing screenshot with: #{resizecmd}"
      p "Reducing screenshot with: #{resizecmd}"
      system(resizecmd)
    rescue
      logger.debug "Couldn't take screenshot!"
    end

		return result
	end
	public

  def record
    dir = record_table

    @result = {'resultDir' => dir}
    ['result', 'numTestFailures', 'numTestPasses', 'numCommandFailures', 'numCommandPasses', 'numCommandErrors', 'totalTime', 'failuresAndErrors'].each do |item|
      @result[item] = params[item]
    end

    File.open(log_path(params[:logFile] || 'default.yml'), 'w') {|f| YAML.dump(@result, f)}

    render :file => view_path('record.rhtml'), :layout => layout_path
  end

  def record_table
    return nil unless @result_dir

    cur_result_dir = File.join(@result_dir, (params[:logFile] || "default").sub(/\.yml$/, ''))
    FileUtils.mkdir_p(cur_result_dir)
    File.open("#{cur_result_dir}/index.html", "wb") do |f|
      f.write <<EOS
<html>
<head><title>Selenium Test Result</title></head>
<frameset cols="30%,*">
<frame name="suite" src="suite.html">
<frame name="testcase" src="blank.html">
</frameset>
</html>
EOS
    end
    html_header = <<EOS
<html>
<head>
<link rel="stylesheet" type="text/css" href="selenium-test.css">
</head>
<body>
EOS
    html_footer = "</body></html>\n"
    if selenium_path
      css_file = File.join selenium_path, "selenium-test.css"
      if File.exist?(css_file)
        FileUtils.cp css_file, cur_result_dir
      end
    end
    File.open("#{cur_result_dir}/blank.html", "wb") do |f|
      f.write "<html><body></body></html>"
    end
    File.open("#{cur_result_dir}/suite.html", "wb") do |f|
      suite = params[:suite]
      suite.sub!(/^.*(<table[\s>])/im, '\1')
      i = 1
      suite.gsub!(/(\shref=)"[^"]*"/i) do |m|
        link = "#{$1}\"test#{i}.html\" target=\"testcase\""
        File.open("#{cur_result_dir}/test#{i}.html", "wb") do |testcase|
          testcase.write html_header
          testcase.write(params["testTable.#{i}"])
          testcase.write html_footer
        end
        i += 1
        link
      end
      f.write html_header
      f.write suite
      f.write html_footer
    end
    cur_result_dir
  end

  private :record_table
end
