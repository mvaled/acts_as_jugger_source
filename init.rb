# -*- encoding: utf-8 -*-

require 'acts_as_jugger_source'

config.gem 'juggernaut'

ActiveRecord::Base.class_eval do
  include ::Acts::JuggerSource unless ActiveRecord::Base.include? ::Acts::JuggerSource
end
