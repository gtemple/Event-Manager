require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(phone)
  num = phone.to_s.gsub(/\D+/, '')
  if num.length == 11 && num[0] == '1'
    num[0] == ''
  elsif num.length != 10
    num = '0000000000'
  end
end

def popular_registration_time(sheet, period)
  hours = []
  weekdays = []
  sheet.each do |row|
    reg_date = row[:regdate]
      hours << DateTime.strptime(reg_date, '%m/%d/%Y %H:%M').hour.to_i
      weekdays << DateTime.strptime(reg_date, '%m/%d/%Y %H:%M').wday.to_i
  end
  hours = hours.group_by { |n| n }.values.max_by(&:size).first
  weekdays = Date::DAYNAMES[((weekdays.group_by { |n| n }.values.max_by(&:size).first) + 1) % 7]
  if period  == 'hour'
  puts "The most popular registration period of the day is between #{hours * 100} and #{hours * 100 + 100}."
  elsif period == 'day'
    puts "The most popular registration day of the week is #{weekdays}"
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename,'w') do |file|
    file.puts form_letter
  end
end

puts "EventManager initialized."

contents = CSV.open 'event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read "form_letter.erb"
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

contents.rewind
popular_registration_time(contents, 'hour')
contents.rewind
popular_registration_time(contents, 'day')