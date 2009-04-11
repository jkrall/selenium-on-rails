module ActionController
  module Routing #:nodoc:
    class RouteSet #:nodoc:
      alias_method :draw_without_selenium_routes, :draw
      def draw
        draw_without_selenium_routes do |map|
          yield map if block_given?
          map.connect 'selenium/setup',
            :controller => 'selenium', :action => 'setup'
          map.connect 'selenium/tests/*testname',
            :controller => 'selenium', :action => 'test_file'
          map.connect 'selenium/postResults',
            :controller => 'selenium', :action => 'record'
          map.connect 'selenium/postResults/:logFile',
            :controller => 'selenium', :action => 'record', :requirements => { :logFile => /.*/ }
          map.connect 'selenium/screenshot',
            :controller => 'selenium', :action => 'screenshot'
          map.connect 'selenium/*filename',
            :controller => 'selenium', :action => 'support_file'
          map.connect 'switch_environment',
            :controller => 'switch_environment', :action => 'index'  
        end
      end
    end
  end
end
