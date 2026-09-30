# frozen_string_literal: true

require "resolv"

module HasDNSChecks

  def dns_ok?
    return spf_status == "OK" && dkim_status == "OK" && return_path_status == "OK" if individual_dns?

    spf_status == "OK" && dkim_status == "OK" && %w[OK Missing].include?(mx_status) && %w[OK Missing].include?(return_path_status)
  end

  def dns_checked?
    spf_status.present?
  end

  def check_dns(source = :manual)
    check_spf_record
    check_dkim_record
    check_mx_records
    check_return_path_record
    self.dns_checked_at = Time.now
    save!
    if source == :auto && !dns_ok? && owner.is_a?(Server)
      WebhookRequest.trigger(owner, "DomainDNSError", {
        server: owner.webhook_hash,
        domain: name,
        uuid: uuid,
        dns_checked_at: dns_checked_at.to_f,
        spf_status: spf_status,
        spf_error: spf_error,
        dkim_status: dkim_status,
        dkim_error: dkim_error,
        mx_status: mx_status,
        mx_error: mx_error,
        return_path_status: return_path_status,
        return_path_error: return_path_error
      })
    end
    dns_ok?
  end

  #
  # SPF
  #

  def check_spf_record
    return check_individual_spf_record if individual_dns?

    result = resolver.txt(name)
    spf_records = result.grep(/\Av=spf1/)
    if spf_records.empty?
      self.spf_status = "Missing"
      self.spf_error = "No SPF record exists for this domain"
    else
      suitable_spf_records = spf_records.grep(/include:\s*#{Regexp.escape(Postal::Config.dns.spf_include)}/)
      if suitable_spf_records.empty?
        self.spf_status = "Invalid"
        self.spf_error = "An SPF record exists but it doesn't include #{Postal::Config.dns.spf_include}"
        false
      else
        self.spf_status = "OK"
        self.spf_error = nil
        true
      end
    end
  end

  def check_spf_record!
    check_spf_record
    save!
  end

  #
  # DKIM
  #

  def check_dkim_record
    domain = "#{dkim_record_name}.#{name}"
    records = resolver.txt(domain)
    if records.empty?
      self.dkim_status = "Missing"
      self.dkim_error = "No TXT records were returned for #{domain}"
    else
      sanitised_dkim_record = records.first.strip.ends_with?(";") ? records.first.strip : "#{records.first.strip};"
      if records.size > 1
        self.dkim_status = "Invalid"
        self.dkim_error = "There are #{records.size} records for at #{domain}. There should only be one."
      elsif sanitised_dkim_record != dkim_record
        self.dkim_status = "Invalid"
        self.dkim_error = "The DKIM record at #{domain} does not match the record we have provided. Please check it has been copied correctly."
      else
        self.dkim_status = "OK"
        self.dkim_error = nil
        true
      end
    end
  end

  def check_dkim_record!
    check_dkim_record
    save!
  end

  #
  # MX
  #

  def check_mx_records
    return if individual_dns?

    records = resolver.mx(name).map(&:last)
    if records.empty?
      self.mx_status = "Missing"
      self.mx_error = "There are no MX records for #{name}"
    else
      missing_records = Postal::Config.dns.mx_records.dup - records.map { |r| r.to_s.downcase }
      if missing_records.empty?
        self.mx_status = "OK"
        self.mx_error = nil
      elsif missing_records.size == Postal::Config.dns.mx_records.size
        self.mx_status = "Missing"
        self.mx_error = "You have MX records but none of them point to us."
      else
        self.mx_status = "Invalid"
        self.mx_error = "MX #{missing_records.size == 1 ? 'record' : 'records'} for #{missing_records.to_sentence} are missing and are required."
      end
    end
  end

  def check_mx_records!
    check_mx_records
    save!
  end

  #
  # Return Path
  #

  def check_return_path_record
    records = resolver.cname(return_path_domain)
    if records.empty?
      self.return_path_status = "Missing"
      self.return_path_error = "There is no return path record at #{return_path_domain}"
    elsif records.size == 1 && records.first == return_path_target
      return check_individual_return_path_target if individual_dns?

      self.return_path_status = "OK"
      self.return_path_error = nil
    else
      self.return_path_status = "Invalid"
      self.return_path_error = "There is a CNAME record at #{return_path_domain} but it points to #{records.first} which is incorrect. It should point to #{return_path_target}."
    end
  end

  def check_return_path_record!
    check_return_path_record
    save!
  end

  private

  def check_individual_spf_record
    records = resolver.txt(name).grep(/\Av=spf1(?:\s|\z)/)
    policy = resolver.txt(spf_include).grep(/\Av=spf1(?:\s|\z)/)
    if records.empty?
      self.spf_status = "Missing"
      self.spf_error = "No SPF record exists for this domain"
    elsif records.size != 1 || !records.first.split.any? { |term| ["include:#{spf_include}", "+include:#{spf_include}"].include?(term) }
      self.spf_status = "Invalid"
      self.spf_error = "Publish one SPF record including #{spf_include}"
    elsif policy.size != 1 || !policy.first.split.any? { |term| term.match?(/\A\+?ip[46]:/) }
      self.spf_status = "Invalid"
      self.spf_error = "Publish one SPF TXT record at #{spf_include} containing your sending IP addresses (ip4: or ip6:)"
    else
      self.spf_status = "OK"
      self.spf_error = nil
    end
    spf_status == "OK"
  end

  def check_individual_return_path_target
    target = return_path_target
    addresses = resolver.a(target) + resolver.aaaa(target)
    mx = resolver.mx(target).map(&:last)
    spf = resolver.txt(target).grep(/\Av=spf1(?:\s|\z)/)
    if addresses.empty?
      self.return_path_error = "Add an A or AAAA record at #{target} pointing to your Postal SMTP server"
    elsif mx.any? && mx.any? { |host| host.downcase != target }
      self.return_path_error = "The MX record at #{target} should point to #{target} itself"
    elsif spf.size != 1 || !spf.first.split.any? { |term| ["include:#{spf_include}", "+include:#{spf_include}"].include?(term) }
      self.return_path_error = "Publish one SPF TXT record at #{target} including #{spf_include}"
    else
      self.return_path_status = "OK"
      self.return_path_error = nil
      return true
    end
    self.return_path_status = "Invalid"
    false
  end

end

# -*- SkipSchemaAnnotations
