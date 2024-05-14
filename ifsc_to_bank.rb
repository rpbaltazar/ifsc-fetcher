# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'
require 'csv'

def load_ifsc_codes(filename)
  File.readlines(filename, chomp: true)
end

def bank_name_from_ifsc(ifsc)
  URI.open("https://ifsc.bankifsccode.com/#{ifsc}") do |f|
    doc = Nokogiri::HTML(f)
    if doc.at_css('title')
      title = doc.at_css('title').text
      title_parts = title.split(",")
      if title_parts[-2].downcase.include?("bank")
        bank_name = title_parts[-2]
      else
        bank_name = title_parts[-1]
        bank_name.slice!("BankIFSCcode.com")
      end
      return [ifsc, bank_name]
    end
    return [ifsc, "NOT FOUND"]
  end
end

filename = ARGV[0]
file_chunk = ARGV[1]
start_from_idx = ARGV[2].to_i

ifsc_codes = load_ifsc_codes(filename)
parts = ifsc_codes.each_slice(1200).to_a
list_to_process = parts[file_chunk.to_i]
p list_to_process

CSV.open("resolved_chunk_#{file_chunk}.csv", "a+") do |csv|
  list_to_process.each_with_index do |ifsc, idx|
    next if idx < start_from_idx

    begin
      row = bank_name_from_ifsc(ifsc)
      csv << row
    rescue Exception => error
      p "RESTART FROM: #{idx} | #{error}"
      raise error
    end
  end
end
