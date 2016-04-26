class IndexNodesServiceParamError < StandardError
  attr_accessor :type, :operation
  def initialize(_type, _operation)
    @type, @operation = _type, _operation
    super("#{_operation}")
  end
end

class IndexNodesService

  attr_reader :automation_service

  def initialize(_automation_service)
    if _automation_service.blank?
      raise IndexNodesServiceParamError.new('automation_service', 'Automation service parameter empty.')
    end
    @automation_service = _automation_service
  end

  def list_nodes_with_jobs(page, per_page)
    nodes = @automation_service.nodes("", ['online', 'platform_family', 'platform_version', 'hostname', 'os', 'ipaddress'], page, per_page)
    jobs = {}
    nodes[:elements].each do |a|
      jobs[a.id.to_sym] = @automation_service.jobs(a.id, 1, 5)
    end
    nodes[:jobs] = jobs
    nodes
  end

end