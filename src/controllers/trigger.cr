require "gpio"

# a controller for manually activating the trigger
class App::Trigger < App::Base
  base "/api/trigger"

  IO_CHIP_PATH        = Path[ENV["IO_CHIP_PATH"]? || "/dev/gpiochip0"]
  RELAY_TRIGGER_LINE  = (ENV["RELAY_TRIGGER_LINE"]? || "26").to_i

  class_getter io_chip : GPIO::Chip do
    GPIO.default_consumer = "ai trigger"
    GPIO::Chip.new(IO_CHIP_PATH)
  end

  class_getter trigger_relay : GPIO::Line do
    line = io_chip.line(RELAY_TRIGGER_LINE)
    line.request_output
    line
  end

  class_getter mutex : Mutex = Mutex.new

  def self.activate_for(time : Time::Span)
    @@mutex.synchronize do
      trigger_relay.set_low
      sleep time
      trigger_relay.set_high
    end
  end

  # change the state of the chicken door
  @[AC::Route::POST("/activate")]
  def activate(relay_time : Int32 = 500) : Nil
    self.class.activate_for relay_time.milliseconds
  end

  enum State
    High
    Low
  end

  # change the state of the chicken door
  @[AC::Route::POST("/activate/manual/:state")]
  def manual_state(state : State) : Nil
    case state
    in .high?
      self.class.trigger_relay.set_high
    in .low?
      self.class.trigger_relay.set_low
    end
  end

  # this file is built as part of the docker build
  OPENAPI = YAML.parse(File.exists?("openapi.yml") ? File.read("openapi.yml") : "{}")

  # returns the OpenAPI representation of this service
  @[AC::Route::GET("/openapi")]
  def openapi : YAML::Any
    OPENAPI
  end
end
