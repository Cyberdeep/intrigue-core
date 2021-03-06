module Intrigue
module Task
class EnrichDnsRecord < BaseTask

  def self.metadata
    {
      :name => "enrich/dns_record",
      :pretty_name => "Enrich DnsRecord",
      :authors => ["jcran"],
      :description => "Look up all names of a given entity.",
      :references => [],
      :allowed_types => ["DnsRecord"],
      :type => "enrichment",
      :passive => true,
      :example_entities => [{"type" => "DnsRecord", "details" => {"name" => "intrigue.io"}}],
      :allowed_options => [],
      :created_types => []
    }
  end

  def run
    super

    lookup_name = _get_entity_name

    ########################
    ## Handle ANY Records ##
    ########################
    results = resolve(lookup_name)

    ####
    ### Create aliased entities
    ####
    results.each do |result|

      _log "Creating entity for... #{result["name"]}"
      if "#{result["name"]}".is_ip_address?
        _create_entity("IpAddress", { "name" => result["name"] }, @entity)
      else
        _create_entity("DnsRecord", { "name" => result["name"] }, @entity)
      end
    end

    ####
    ### Set details for this entity
    ####
    dns_entries = []
    results.each do |result|

      # Clean up the dns data
      xtype = result["lookup_details"].first["response_record_type"].to_s.sanitize_unicode

      lookup_details = result["lookup_details"].first["response_record_data"]
      if lookup_details.kind_of?(Dnsruby::IPv4) || lookup_details.kind_of?(Dnsruby::IPv6) || lookup_details.kind_of?(Dnsruby::Name)
        _log "Sanitizing Dnsruby Object"
        xdata = result["lookup_details"].first["response_record_data"].to_s.sanitize_unicode
      else
        _log "Sanitizing String or array"
        xdata = result["lookup_details"].first["response_record_data"].to_s.sanitize_unicode
      end

      dns_entries << { "response_data" => xdata, "response_type" => xtype }
    end
    _set_entity_detail("dns_entries", dns_entries.uniq )
    @entity.save

    ###
    ### MAGIC
    ###
    ### For each associated IpAddress, make sure we create any additional
    ### uris if we already have scan results
    ###
    @entity.aliases.each do |a|
      next unless a.type_string == "IpAddress" #  only ips
      #next if a.hidden # skip hidden
      existing_ports = a.get_detail("ports")
      if existing_ports
        existing_ports.each do |p|
        #  next unless p["number"] == 80 || unless p["number"] == 443
          _create_network_service_entity(a,p["number"],p["protocol"],{})
        end
      end
    end

    _finalize_enrichment
  end

end
end
end
