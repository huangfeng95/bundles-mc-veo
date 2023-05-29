#! /usr/bin/env ruby

require 'orocos'
require 'rock/bundle'
require 'orocos/async'
require 'vizkit'
require 'optparse'

options = {}
options[:taskname] = 'mc_veo'
options[:hostname] = nil
options[:logfile] = nil

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    mc_veo_visualization [options]
    EOD
    opt.on '--task=TASKNAME', String, 'OROCOS Task name (mc_veo by default)' do |taskname|
        options[:taskname] = taskname
    end

    opt.on '--host=HOSTNAME', String, 'the host we should contact to find RTT tasks' do |host|
        options[:hostname] = host
    end

    opt.on '--log=LOGFILE', String, 'path to the log file' do |log|
        options[:logfile] = log
    end

    opt.on '--help', 'this help message' do
        puts opt
        exit 0
    end
end

args = op.parse(ARGV)

if options[:hostname]
    Orocos::CORBA.name_service.ip = options[:hostname]
end

# load log files and add the loaded tasks to the Orocos name service
log_replay = Orocos::Log::Replay.open(options[:logfile]) unless options[:logfile].nil?

# If log replay track only needed ports
unless options[:logfile].nil?
    log_replay.track(true)
    #log_replay.transformer_broadcaster.rename('foo')
end


Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize

color = Vizkit.vizkit3d_widget.getBackgroundColor()
color.setRgb(255, 255, 255) #white
Vizkit.vizkit3d_widget.setBackgroundColor(color)
Vizkit.vizkit3d_widget.setCameraManipulator("Trackball")
grid = Vizkit.vizkit3d_widget.grid # Get the grid
grid.enabled = false # disable the grid view by default

# KeyFrame map point cloud visualizer 
local_map = Vizkit.default_loader.PointcloudVisualization
local_map.setKeepOldData(true)
local_map.setMaxOldData(1)
local_map.setPluginName("Local Map")
Vizkit.vizkit3d_widget.setPluginDataFrame("world", local_map)

# Global map point cloud visualizer
global_map = Vizkit.default_loader.PointcloudVisualization
global_map.setKeepOldData(true)
global_map.setMaxOldData(1)
global_map.setPluginName("Global Map")
Vizkit.vizkit3d_widget.setPluginDataFrame("world", global_map)

# Camera trajectory
trajectory = Vizkit.default_loader.TrajectoryVisualization
trajectory.setLineWidth(10.0)
trajectory.setColor(Eigen::Vector3.new(1, 0, 0)) #Red line
trajectory.setPluginName("Trajectory")
Vizkit.vizkit3d_widget.setPluginDataFrame("world", trajectory)

# KeyFrame camera Frustum
frustum_file_green = Bundles.find_file('data', 'gui/frustum_green_.ply')

# EventFrame camera Frustum
frustum_file = Bundles.find_file('data', 'gui/frustum_red_.ply')
ef_vis = Vizkit.vizkit3d_widget.loadPlugin("vizkit3d","ModelVisualization")
ef_vis.setModelPath(frustum_file)
ef_vis.setPluginName("Event Frame")
Vizkit.vizkit3d_widget.setPluginDataFrame("ef", ef_vis )

# Image Frames visualization
inv_depth_img = Vizkit.default_loader.ImageViewOld
inv_depth_img.windowTitle = "Inverse depth"
event_frame = Vizkit.default_loader.ImageViewOld
event_frame.windowTitle = "Event frame"
model_frame = Vizkit.default_loader.ImageViewOld
model_frame.windowTitle = "Model frame"
residuals_img = Vizkit.default_loader.ImageViewOld
residuals_img.windowTitle = "Events-to-Model Residuals"
keyframes_frame = Vizkit.default_loader.ImageViewOld
keyframes_frame.windowTitle = "KeyFrames"
of_frame = Vizkit.default_loader.ImageViewOld
of_frame.windowTitle = "Optical Flow"

# Sliding window
kfs_array = []

## mc-veo in Asynchronous mode
mc_veo = Orocos::Async.proxy options[:taskname]

mc_veo.on_reachable do

    # Keyframe Point cloud
    local_map.setPointSize(3.0)
    Vizkit.display mc_veo.port('local_map'), :widget =>local_map

    # Global Point cloud
    global_map.setPointSize(3.0)
    Vizkit.display mc_veo.port('global_map'), :widget =>global_map

    # KFs pose
    mc_veo.port('pose_w_kfs').on_data do |array|
        # Clean previous plugins
        kfs_array.each do |p|
            Vizkit.vizkit3d_widget.removePlugin(p)
        end
        # Remove object
        kfs_array.clear

        # Update the sliding window of KFs
        array.kfs.each do |pose|
            #puts "KF: #{pose.sourceFrame}"
            kf = Vizkit.vizkit3d_widget.loadPlugin("vizkit3d","ModelVisualization")
            kf.setModelPath(frustum_file_green)
            kf.setPluginName("KF["+pose.sourceFrame+"]")
            kf.setScale(0.6)
            Vizkit.vizkit3d_widget.setPluginDataFrame(pose.sourceFrame, kf)
            Vizkit.vizkit3d_widget.setTransformation(pose.targetFrame, pose.sourceFrame,
                    Qt::Vector3D.new(pose.position[0], pose.position[1], pose.position[2]),
                    Qt::Quaternion.new(Qt::Vector4D.new(pose.orientation.x, pose.orientation.y, pose.orientation.z, pose.orientation.w)))
            kfs_array.push(kf)
        end
        # Disable transformer Viz
        Vizkit.vizkit3d_widget.setTransformer(false)
    end

    # KF trajectory
    mc_veo.port('pose_w_kf').on_data do |t_w_kf,_|
        Vizkit.vizkit3d_widget.setTransformation("world","kf",
                    Qt::Vector3D.new(t_w_kf.position[0], t_w_kf.position[1], t_w_kf.position[2]),
                    Qt::Quaternion.new(Qt::Vector4D.new(t_w_kf.orientation.x, t_w_kf.orientation.y, t_w_kf.orientation.z, t_w_kf.orientation.w)))
    end

    # EF trajectory
    mc_veo.port('pose_w_ef').on_data do |t_w_ef,_|
        trajectory.updateTrajectory(t_w_ef.position)
        Vizkit.vizkit3d_widget.setTransformation("world","ef",
                    Qt::Vector3D.new(t_w_ef.position[0], t_w_ef.position[1], t_w_ef.position[2]),
                    Qt::Quaternion.new(Qt::Vector4D.new(t_w_ef.orientation.x, t_w_ef.orientation.y, t_w_ef.orientation.z, t_w_ef.orientation.w)))
    end

    # inv depth frame
    Vizkit.display mc_veo.port("inv_depth_frame"), :widget => inv_depth_img

    # event frame
    Vizkit.display mc_veo.port("event_frame"), :widget => event_frame

    # brightness model frame
    Vizkit.display mc_veo.port("model_frame"), :widget => model_frame

    # frame of optmization residuals
    Vizkit.display mc_veo.port("residuals_frame"), :widget => residuals_img

    # keyframes frame
    Vizkit.display mc_veo.port("keyframes_frame"), :widget => keyframes_frame

    # optical flow frame
    Vizkit.display mc_veo.port("of_frame"), :widget => of_frame

end

# Enable the GUI when the task is reachable
mc_veo.on_reachable {Vizkit.vizkit3d_widget.setEnabled(true)} if options[:logfile].nil?

# Disable the GUI until the task is reachable
mc_veo.on_unreachable {Vizkit.vizkit3d_widget.setEnabled(false)} if options[:logfile].nil?

Vizkit.control log_replay unless options[:logfile].nil?
Vizkit.exec
