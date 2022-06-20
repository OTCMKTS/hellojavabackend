# This (very bizarre file) gets used from `stack_spec.rb`. It tries to reproduce the most interesting (contrived?) call
# stack I can think of, with as many weird variants as possible.
# The objective is to thoroughly test our stack trace sampling abilities.
# Control flow goes from bottom of file to top (e.g. ClassA will be the top of the stack)

# ----

class IbhClassA
  def hello
    $ibh_ready_queue << true
    sleep
  end
end

module IbhModuleB
  class IbhClassB < IbhClassA
    def hello
      super
    end
  end
end

module IbhModuleC
  def self.hello
    IbhModuleB::IbhClassB.new.hello
  end
end

class IbhClassWithStaticMethod
  def self.hello
    IbhModuleC.hello
  end
end

module IbhModuleD
  def hello
    IbhClassWithStaticMethod.hello
  end
end

class IbhClassC
  include IbhModuleD
end

class IbhClassD; end

module IbhGlobals
  $ibh_a_proc = proc { IbhClassC.new.hello }

  $ibh_a_lambda = lambda { $ibh_a_proc.call }

  $ibh_class_d_object = IbhClassD.new

  def $ibh_class_d_object.hello
    $ibh_a_lambda.call
  end
end

class IbhClassE
  def hello
    $ibh_class_d_object.hello
  end
end

class IbhClassG
  def hello
    raise "This should not be called"
  end
end

module IbhContainsRefinement
  module RefinesIbhClassG
    refine IbhClassG do
      def hello
        if RUBY_VERSION >= "2.7.0"
          IbhClassE.instance_method(:hello).bind_call(IbhClassF.new)
        else
          IbhClassE.instance_method(:hello).bind(IbhClassF.new).call
        end
      end
    end
  end
end

module IbhModuleE
  using IbhContainsRefinement::RefinesIbhClassG

  def self.hello
    IbhClassG.new.hello
  end
end

class IbhClassH
  def method_missing(name, *_)
    super unless name == :hello

    IbhModuleE.hello
  end
end

class IbhClassF < IbhClassE
  def hello(arg1, arg2, test1, test2)
    1.times {
      IbhClassH.new.hello
    }
  end
end

IbhClassI = Class.new do
  define_method(:hello) do
    IbhClassF.new.hello(0, 1, 2, 3)
  end
end

module IbhMoreGlobals
  $ibh_singleton_class = Object.new.singleton_class

  def $ibh_singleton_class.hello
    IbhClassI.new.hello
  end

  $ibh_anonymous_instance = Class.new do
    def hello
      $ibh_singleton_class.hello
    end
  end.new

  $ibh_anonymous_module = Module.new do
    d