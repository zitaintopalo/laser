class GemLoader

  def initialize()
    @client = Gems::Client.new
  end

  def get_spec_from_api(gem_name)
    begin
      @client.info(gem_name)
    rescue JSON::ParserError
      nil
    end
  end

  def get_owners_from_api(gem_name)
    @client.owners(gem_name)
  end

  def get_build_dates_api(gem_name)
    versions = @client.versions(gem_name)
    [ versions[0]["built_at"] ,  versions[-1]["built_at"]]
  end

  def create_or_update_spec(gem_name)
    gem_data = get_spec_from_api(gem_name)
    return unless gem_data
    laser_gem = LaserGem.find_or_create_by(name: gem_name)
    laser_gem.touch
    current_version , first_version = get_build_dates_api(laser_gem.name)
    attribs = {laser_gem_id: laser_gem.id,
              build_date: first_version ,
              current_version_creation: current_version }
    spec_attributes.each  { |k,v| attribs[k] = gem_data[v]}
    update_owners(laser_gem)
    if laser_gem.gem_spec
      laser_gem.gem_spec.update(attribs)
    else
      laser_gem.create_gem_spec!(attribs)
    end
    create_or_update_deps(laser_gem, gem_data["dependencies"]["runtime"] )
    laser_gem
  end

  def update_owners(laser_gem )
    owner_array = get_owners_from_api(laser_gem.name)
    owner_array.each do |owner|
      gem_handle = owner["handle"]
      email = owner["email"]
      ownership = Ownership.find_or_create_by(laser_gem_id: laser_gem.id, email: email)
      ownership.update(gem_handle: gem_handle)
    end
  end

  def create_or_update_deps(laser_gem, runtime_deps)
    runtime_deps.each do |gem_dep|
      dep_name = gem_dep["name"]
      ver = gem_dep["requirements"]
      if lg_dep = LaserGem.find_by(name: dep_name)
        create_or_update_spec(lg_dep.name) unless lg_dep.gem_spec.updated_at > 7.day.ago
      else
        lg_dep = LaserGem.create!(name: dep_name)
        create_or_update_spec(lg_dep.name)
      end
      begin
        laser_gem.register_dependency(lg_dep, ver) unless GemDependency.where("laser_gem_id = ? and dependency_id = ?", laser_gem.id, lg_dep.id).exists?
      rescue ActiveRecord::RecordInvalid => e
        puts dep_name + " invalid " + e.message
      end
    end
  end

  private
  def spec_attributes
    {
      name: "name",
      info: "info",
      current_version: "version",
      current_version_downloads: "version_downloads",
      total_downloads: "downloads",
      rubygem_uri: "project_uri",
      documentation_uri: "documentation_uri",
      source_code_uri: "source_code_uri",
      homepage_uri: "homepage_uri",
      bug_tracker_uri: "bug_tracker_uri",
      authors: "authors",
    }
  end
end
