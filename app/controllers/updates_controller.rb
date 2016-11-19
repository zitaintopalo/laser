require "git_loader"
require "gem_loader"

class UpdatesController < ApplicationController
  before_action :authenticate_user!

  def show
  end

  def update
    gem_name = params[:gem_name]
    loader = GemLoader.new
    if LaserGem.find_by(name: gem_name)
      redirect_to laser_gem_path(gem_name), notice: "You have sucessfully requested an update for this gem"
      gem_data_fetch(gem_name)
    elsif loader.get_spec_from_api(gem_name) == nil
      redirect_to updates_show_path, notice: "This does not appear to be a valid gem. Please make sure this gem has been uploaded to rubygems.org"
    else
      redirect_to laser_gem_path(gem_name), notice: "You have sucessfully requested an update for this gem"
      gem_data_fetch(gem_name)
    end
  end

  def gem_data_fetch(gem_name)
    gemloader = GemLoader.new
    gemloader.create_or_update_spec(gem_name)
    gitloader = GitLoader.new
    gitloader.update_or_create_git(gem_name)
    laser_gem = LaserGem.find_by(name: gem_name)
    Ranking.new(laser_gem).total_rank_calc
    Ranking.new(laser_gem).download_rank_string_calc
    Ranking.new(laser_gem).download_rank_percent_calc
  end
end
