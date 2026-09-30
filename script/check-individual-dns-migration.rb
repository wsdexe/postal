# frozen_string_literal: true

# Run only in the isolated CI database, after the regression specs.
abort "This migration check requires RAILS_ENV=test" unless Rails.env.test?

require Rails.root.join("db/migrate/20260930090000_add_individual_dns_names_to_domains")

domain = Domain.create!(name: "migration.example.com", verification_method: "DNS", verified_at: Time.now)
original = domain.attributes.except(*Domain::DNS_NAME_ATTRIBUTES)
migration = AddIndividualDNSNamesToDomains.new
begin
  migration.migrate(:down)
  migration.migrate(:up)
  Domain.reset_column_information
  domain.reload
  raise "Existing domain was modified" unless domain.attributes.except(*Domain::DNS_NAME_ATTRIBUTES) == original
  raise "Existing domain acquired new DNS names" if domain.individual_dns?
  domain.save!
  raise "Saving an existing domain populated new names" if domain.reload.individual_dns?
  puts "Migration preserved the existing domain, its key and its legacy DNS mode."
ensure
  domain.destroy!
end
