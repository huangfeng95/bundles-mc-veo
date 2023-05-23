begin
    require 'rock/bundle'
    require 'pp'
    require 'Qt4'
    require 'qtuitools'
rescue Exception => e
    log = Logger.new(STDOUT)
    log.error "!!! Cannot load Qt4 ruby bindings !!!"
    raise e
end

Bundles.initialize
stl_file = Bundles.find_file('data', 'gui/frustum_red_.ply')
puts stl_file

app = Qt::Application.new(ARGV)
loader = Qt::UiLoader.new()
widget = loader.createWidget("vizkit3d::Vizkit3DWidget")
plugin = widget.loadPlugin("vizkit3d","GridVisualization")
robot = widget.loadPlugin("vizkit3d","ModelVisualization")
robot.setModelPath(stl_file)
robot.setVisualizationFrame("camera")

timer = Qt::Timer.new
angle = 0
y = 0
timer.connect SIGNAL(:timeout) do
    x = -2+2.0 *Math::cos(angle)
    quat = Qt::Quaternion::fromAxisAndAngle(0,0,1,0)
    widget.setTransformation("world","camera",Qt::Vector3D.new(x,y,0.3),quat)
    quat = Qt::Quaternion::fromAxisAndAngle(0,0,1,Math::cos(angle)*90)
    robot.setJointRotation("pan_joint",quat)
    quat = Qt::Quaternion::fromAxisAndAngle(0,1,0,(Math::cos(angle)*30))
    robot.setJointRotation("tilt_joint",quat)
    angle +=0.01
end
timer.start(10)

widget.show
app.exec


