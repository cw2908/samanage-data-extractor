# frozen_string_literal: true

require "samanage"
require "awesome_print"
require "active_support"
require "active_support/core_ext"
require "logger"

class DateTime
  include DateAndTime::Calculations
end
RUN_DATE = DateTime.now.strftime("%b-%d-%Y %H%M")
CONTRACTS_FILENAME = File.join("exports", "Contracts #{RUN_DATE}.csv").freeze
CONFIGURATION_ITEMS_FILENAME = File.join("exports", "Configuration Items #{RUN_DATE}.csv").freeze

@full_run = Dir["./exports/*.csv"].count.zero?
@samanage = Samanage::Api.new(token: ENV["SOLARWINDS_TOKEN"])
@logger = Logger.new($stdout)
@logger.info "Running with @full_run=#{@full_run.inspect}"

def write_csv(hsh:, filename:)
  write_headers = !File.exist?(filename)
  CSV.open(filename, "a+", write_headers: write_headers, force_quotes: true, headers: hsh.keys) do |csv|
    csv << hsh.values
  end
end

task :extract_data do
  begin
    @samanage.authorize
  rescue Samanage::Error, Samanage::InvalidRequest, Samanage::AuthorizationError => e
    error_msg = "#{e.class}: #{e.response}"
    @logger.error error_msg
    write_csv(
      hsh: { error: error_msg },
      filename: File.join("exports", "errors", "API Errors #{RUN_DATE}.csv")
    )
    next
  end
  # Can pass any text as second argument to make it save all records, otherwise it will save only created/updated in the past day.
  # Comment out if CSV will be moved/deleted from this directory

  @options = { verbose: true, per_page: 100 }
  @options["updated[]"] = 1 unless @full_run

  contracts = @samanage.contracts(options: @options)
                       .uniq { |i| i["id"] }
  configuration_items = @samanage.configuration_items(options: @options)
                                 .uniq { |i| i["id"] }
  unless @full_run
    contracts = contracts.select do |contract|
      DateTime.parse(contract["updated_at"]) >= DateTime.now.yesterday.beginning_of_day
    end
  end

  def lookup_custom_field(record:, field:)
    record["custom_fields_values"].to_a
                                  .find { |cfv| cfv["name"] == field }
                                  .to_h["value"]
  end

  def format_contracts(record:, item: {})
    {
      "Name" => record["name"],
      "Manufacturer" => record["manufaturer"],
      "Type" => record["type"],
      "Status" => record["status"],
      "Start Date" => record["start_date"],
      "End Date" => record["end_date"],
      "Note" => record["notes"],
      "Site" => record.dig("site,", "name"),
      "Department" => record.dig("department", "name"),
      "Owner" => record["owner"],
      "Owner Name" => record.dig("owner", "name"),
      "Owner Email" => record.dig("owner", "email"),
      "Technical Owner" => record["technical_owner"],
      "Purchasing Owner" => record["purchasing_owner"],
      "License Type" => lookup_custom_field(record: record, field: "License Type"),
      "Fiscal Year" => lookup_custom_field(record: record, field: "Fiscal Year"),
      "Termination at will?" => lookup_custom_field(record: record, field: "Termination at will?"),
      "Early termination cost" => lookup_custom_field(record: record, field: "Early termination cost"),
      "Automatic Renewal" => lookup_custom_field(record: record, field: "Automatic Renewal"),
      "Transferability / reassignment of contract?" => lookup_custom_field(record: record,
field: "Transferability / reassignment of contract?"),
      "Payment terms" => lookup_custom_field(record: record, field: "Payment terms"),
      "Invoice #" => lookup_custom_field(record: record, field: "Invoice #"),
      "Tags" => lookup_custom_field(record: record, field: "Tags"),
      "Related Contracts" => lookup_custom_field(record: record, field: "Related Contracts"),
      "Total Financial Value" => lookup_custom_field(record: record, field: "Total Financial Value"),
      "Renewal Reminder" => lookup_custom_field(record: record, field: "Renewal Reminder"),
      "Remind Days" => lookup_custom_field(record: record, field: "Remind Days"),
      "Renewal User" => lookup_custom_field(record: record, field: "Renewal User"),
      "Item Name" => lookup_custom_field(record: record, field: "Item Name"),
      "Quantity" => lookup_custom_field(record: record, field: "Quantity"),
      "Version" => lookup_custom_field(record: record, field: "Version"),
      "Date" => lookup_custom_field(record: record, field: "Date"),
      "Item Tag" => lookup_custom_field(record: record, field: "Item Tag"),
      "Number" => lookup_custom_field(record: record, field: "Number"),
      "Recurrence" => lookup_custom_field(record: record, field: "Recurrence"),
      "Total Cost" => lookup_custom_field(record: record, field: "Total Cost"),
      "Currency" => lookup_custom_field(record: record, field: "Currency"),
      "Reseller Name" => lookup_custom_field(record: record, field: "Reseller Name"),
      "item_number": item["number"],
      "item_name": item["name"],
      "item_version": item["version"],
      "item_quantity": item["quantity"],
      "item_language": item["language"],
      "item_date": item["date"],
      "item_rate": item["rate"],
      "item_notes": item["notes"],
      "item_created_at": item["created_at"],
      "item_updated_at": item["updated_at"],
      "item_tag": item["tag"]
    }
  end

  def format_configuration_items(record:)
    {
      "Name" => record["name"],
      "Asset ID" => record["asset_id"],
      "State" => record["state"],
      "Type" => record.dig("type", "name"),
      "Site" => record.dig("site", "name"),
      "Department" => record.dig("site", "name"),
      "Service Name" => lookup_custom_field(record: record, field: "Service Name"),
      "Service Short Name" => lookup_custom_field(record: record, field: "Service Short Name"),
      "Service_URLs" => lookup_custom_field(record: record, field: "Service_URLs"),
      "Publicly Facing?" => lookup_custom_field(record: record, field: "Publicly Facing?"),
      "Pillar" => lookup_custom_field(record: record, field: "Pillar"),
      "Contract on file?" => lookup_custom_field(record: record, field: "Contract on file?"),
      "Contract" => lookup_custom_field(record: record, field: "Contract"),
      "Documentation" => lookup_custom_field(record: record, field: "Documentation"),
      "Disaster Recovery" => lookup_custom_field(record: record, field: "Disaster Recovery"),
      "SLA Tier" => lookup_custom_field(record: record, field: "SLA Tier"),
      "Do Not Monitor" => lookup_custom_field(record: record, field: "Do Not Monitor"),
      "Do Not Escalate Monitor" => lookup_custom_field(record: record, field: "Do Not Escalate Monitor"),
      "Monitor_Escalation" => lookup_custom_field(record: record, field: "Monitor_Escalation"),
      "Can we modify?" => lookup_custom_field(record: record, field: "Can we modify?"),
      "Type of Authentication (User)" => lookup_custom_field(record: record, field: "Type of Authentication (User)"),
      "Software Platform" => lookup_custom_field(record: record, field: "Software Platform"),
      "Continuous Integration Status (CI)" => lookup_custom_field(record: record,
field: "Continuous Integration Status (CI)"),
      "Continuous Deployment Status (CD)" => lookup_custom_field(record: record,
field: "Continuous Deployment Status (CD)"),
      "VPN Required?" => lookup_custom_field(record: record, field: "VPN Required?"),
      "IPv6" => lookup_custom_field(record: record, field: "IPv6"),
      "DNSSEC" => lookup_custom_field(record: record, field: "DNSSEC"),
      "Data Confidentiality" => lookup_custom_field(record: record, field: "Data Confidentiality"),
      "Data Integrity" => lookup_custom_field(record: record, field: "Data Integrity"),
      "Data Availability" => lookup_custom_field(record: record, field: "Data Availability"),
      "Hosting Type" => lookup_custom_field(record: record, field: "Hosting Type"),
      "Data Storage Format: Flat Files" => lookup_custom_field(record: record,
field: "Data Storage Format: Flat Files"),
      "Data Storage Format: MariaDB" => lookup_custom_field(record: record, field: "Data Storage Format: MariaDB"),
      "Data Storage Format: MSSQL" => lookup_custom_field(record: record, field: "Data Storage Format: MSSQL"),
      "Data Storage Format: Oracle" => lookup_custom_field(record: record, field: "Data Storage Format: Oracle"),
      "Data Storage Format: S3" => lookup_custom_field(record: record, field: "Data Storage Format: S3"),
      "Data Storage Format: SaaS" => lookup_custom_field(record: record, field: "Data Storage Format: SaaS"),
      "Data Storage Format: Redis" => lookup_custom_field(record: record, field: "Data Storage Format: Redis"),
      "Data Storage Format: Kafka" => lookup_custom_field(record: record, field: "Data Storage Format: Kafka"),
      "Data Storage Format: MongoDB" => lookup_custom_field(record: record, field: "Data Storage Format: MongoDB"),
      "Data Storage Format: None" => lookup_custom_field(record: record, field: "Data Storage Format: None"),
      "Executive Owner" => lookup_custom_field(record: record, field: "Executive Owner"),
      "Business Owner" => lookup_custom_field(record: record, field: "Business Owner"),
      "Relationship Delivery Manager" => lookup_custom_field(record: record, field: "Relationship Delivery Manager"),
      "Operations Owner" => lookup_custom_field(record: record, field: "Operations Owner"),
      "Technical Owner" => lookup_custom_field(record: record, field: "Technical Owner"),
      "Data Steward" => lookup_custom_field(record: record, field: "Data Steward"),
      "Business Rationale" => lookup_custom_field(record: record, field: "Business Rationale"),
      "Service Consumer" => lookup_custom_field(record: record, field: "Service Consumer"),
      "GDPR Sensitive Data" => lookup_custom_field(record: record, field: "GDPR Sensitive Data"),
      "ICANN Staff Data only" => lookup_custom_field(record: record, field: "ICANN Staff Data only"),
      "Store IP Address" => lookup_custom_field(record: record, field: "Store IP Address"),
      "Store IP Address Reason" => lookup_custom_field(record: record, field: "Store IP Address Reason"),
      "Data Retention Rules" => lookup_custom_field(record: record, field: "Data Retention Rules"),
      "Terms of Service Link" => lookup_custom_field(record: record, field: "Terms of Service Link"),
      "Terms of Service Reason" => lookup_custom_field(record: record, field: "Terms of Service Reason"),
      "Privacy Policy Link" => lookup_custom_field(record: record, field: "Privacy Policy Link"),
      "Privacy Policy Link Reason" => lookup_custom_field(record: record, field: "Privacy Policy Link Reason"),
      "Cookies Policy Link" => lookup_custom_field(record: record, field: "Cookies Policy Link"),
      "Cookies Policy Reason" => lookup_custom_field(record: record, field: "Cookies Policy Reason"),
      "Cookies Popup/Notice" => lookup_custom_field(record: record, field: "Cookies Popup/Notice"),
      "Cookies Notice Reason" => lookup_custom_field(record: record, field: "Cookies Notice Reason"),
      "Privacy Banner" => lookup_custom_field(record: record, field: "Privacy Banner"),
      "Privacy Banner Reason" => lookup_custom_field(record: record, field: "Privacy Banner Reason"),
      "PII Acknowledgement Statement" => lookup_custom_field(record: record, field: "PII Acknowledgement Statement"),
      "PII Acknowledgement Statement Reason" => lookup_custom_field(record: record,
field: "PII Acknowledgement Statement Reason"),
      "Included in Enterprise Logging" => lookup_custom_field(record: record, field: "Included in Enterprise Logging"),
      "Enterprise Logging Reason" => lookup_custom_field(record: record, field: "Enterprise Logging Reason"),
      "Patch Update Subscription" => lookup_custom_field(record: record, field: "Patch Update Subscription"),
      "UA: Long Address" => lookup_custom_field(record: record, field: "UA: Long Address"),
      "UA: International Domain Names" => lookup_custom_field(record: record, field: "UA: International Domain Names"),
      "UA: Unicode" => lookup_custom_field(record: record, field: "UA: Unicode"),
      "UA: Punicode" => lookup_custom_field(record: record, field: "UA: Punicode"),
      "Platform Reduction: Plan" => lookup_custom_field(record: record, field: "Platform Reduction: Plan")
    }
  end



  ## Export each CI
  configuration_items.each do |configuration_item|
    @logger.info "Extracting: #{configuration_item['name']} => https://app.samanage.com/configuration_item/#{configuration_item['id']}"
    write_csv(hsh: format_configuration_items(record: configuration_item), filename: CONFIGURATION_ITEMS_FILENAME)
  end

  # Export each contract & items
  contracts.each do |contract|
    @logger.info "Extracting: #{contract['name']} => https://app.samanage.com/contract/#{contract['id']}"
    # Write if no items
    if contract["items"].to_a.count.zero?
      write_csv(hsh: format_contracts(record: contract), filename: CONTRACTS_FILENAME)
    else
      # Write new row per items
      contract["items"].each_with_index do |item, index|
        item_data = { "number" => index }.merge(item)
        write_csv(hsh: format_contracts(record: contract.merge(item_data)), filename: CONTRACTS_FILENAME)
      end
    end
  end
end
