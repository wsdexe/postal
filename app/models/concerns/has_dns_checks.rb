# frozen_string_literal: true

require "resolv"

module HasDNSChecks

  def dns_ok?
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
    result = resolver.txt(name)
    spf_records = result.grep(/\Av=spf1/)
    if spf_records.empty?
      self.spf_status = "Missing"
      self.spf_error = "No SPF record exists for this domain"
    else
      suitable_spf_records = spf_records.select { |record| spf_record_satisfies_required_mechanisms?(record) }
      if suitable_spf_records.empty?
        self.spf_status = "Invalid"
        self.spf_error = "An SPF record exists but it doesn't include #{spf_mechanisms.to_sentence}"
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
    spf_records = resolver.txt(return_path_domain).grep(/\Av=spf1/)
    mx_records = resolver.mx(return_path_domain).map { |_, host| normalize_dns_name(host) }
    required_mx_records = return_path_mx_records.map { |host| normalize_dns_name(host) }
    missing_mx_records = required_mx_records - mx_records
    spf_valid = spf_records.any? { |record| spf_record_satisfies_required_mechanisms?(record) }

    if spf_records.empty? && mx_records.empty?
      self.return_path_status = "Missing"
      self.return_path_error = "There are no return path records at #{return_path_domain}"
    elsif spf_valid && missing_mx_records.empty?
      self.return_path_status = "OK"
      self.return_path_error = nil
    else
      errors = []
      if spf_records.empty?
        errors << "There is no SPF record at #{return_path_domain}."
      elsif !spf_valid
        errors << "The SPF record at #{return_path_domain} doesn't include #{spf_mechanisms.to_sentence}."
      end
      if missing_mx_records.present?
        errors << "MX #{'record'.pluralize(missing_mx_records.size)} for #{missing_mx_records.to_sentence} #{missing_mx_records.size == 1 ? 'is' : 'are'} missing."
      end

      self.return_path_status = "Invalid"
      self.return_path_error = errors.join(" ")
    end
  end

  def check_return_path_record!
    check_return_path_record
    save!
  end

  private

  def spf_record_satisfies_required_mechanisms?(record)
    record_mechanisms = record.to_s.split(/\s+/)
    spf_mechanisms.all? { |mechanism| record_mechanisms.include?(mechanism) }
  end

  def normalize_dns_name(name)
    name.to_s.downcase.chomp(".")
  end

end

# -*- SkipSchemaAnnotations
