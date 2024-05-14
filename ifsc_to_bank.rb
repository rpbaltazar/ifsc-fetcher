# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'
require 'csv'

class IfscCode
  def initialize(bank_name, ifsc_code)
    @bank_name = bank_name
    @ifsc_code = ifsc_code
  end

  def to_csv
    [@ifsc_code, @bank_name]
  end
end

class IfscSource
  URL_BASE = 'https://ifsc.bankifsccode.com'

  def initialize; end

  def fetch_ifsc_info(ifsc)
    URI.open("#{URL_BASE}/#{ifsc}") do |f|
      doc = Nokogiri::HTML(f)
      title = doc.at_css('title')
      bank_name = find_bank_name(title.text) if title
      return IfscCode.new('NOT FOUND', ifsc) unless bank_name

      IfscCode.new(bank_name, ifsc)
    end
  rescue StandardError => e
    p e.inspect
    IfscCode.new('FAILED TO FETCH', ifsc)
  end

  private

  def find_bank_name(title)
    title_parts = title.split(',')
    if title_parts[-2].downcase.include?('bank')
      bank_name = title_parts[-2]
    else
      bank_name = title_parts[-1]
      bank_name.slice!('BankIFSCcode.com')
    end
    bank_name
  end
end

class IfscFetcher
  # MAX_FIBERS = 10

  def initialize(source, output)
    @filename = source
    @output = output
    @ifsc_codes = load_ifsc_codes(source)
    @ifsc_parser = IfscSource.new
  end

  def execute
    file_chunk = 0
    parts = @ifsc_codes.each_slice(1200).to_a
    list_to_process = parts[file_chunk.to_i]
    p list_to_process

    CSV.open("output/#{@output}.csv", 'a+') do |csv|
      list_to_process.each do |ifsc|
        parsed_ifsc_code = @ifsc_parser.fetch_ifsc_info(ifsc)

        p parsed_ifsc_code.inspect

        csv << parsed_ifsc_code.to_csv
      end
    end
  end

  private

  def load_ifsc_codes(filename)
    File.readlines(filename, chomp: true)
  end
end

filename = ARGV[0]
output = ARGV[1]
ifsc_fetcher = IfscFetcher.new(filename, output)
ifsc_fetcher.execute
