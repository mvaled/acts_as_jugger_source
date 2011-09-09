require 'test_helper'
require 'shoulda'

class SomeModel < ActiveRecord::Base
  attr_accessor :flags

  acts_as_jugger_source do |operation, model, instance|
    @flags ||= []
    @flags << operation
  end
end

class ActsAsJuggerSourceTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  context 'Metaprogramming' do
    should 'have the after methods' do
      assert SomeModel.instance_methods.include? 'acts_as_jugger_after_save'
      assert SomeModel.instance_methods.include? 'acts_as_jugger_after_create'
      assert SomeModel.instance_methods.include? 'acts_as_jugger_after_destroy'
    end
  end

  context 'Operational tests' do
    setup do
      @instance = SomeModel.new
    end

    should 'call after_create' do
      assert @instance.flags.include? :created
    end
  end
end
