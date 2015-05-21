require 'rest-client'
require 'json'
require 'date'
require 'csv'
require 'yaml'

CONFIG = YAML.load_file('./secrets/secrets.yml')

date = Date.today-1

file_date = date.strftime("%Y%m")
csv_file_name = "crashes_#{CONFIG["package_name"]}_#{file_date}.csv"

system "BOTO_PATH=./secrets/.boto gsutil/gsutil cp gs://#{CONFIG["app_repo"]}/crashes/#{csv_file_name} ."

class Slack
  def self.notify(message)
  
    RestClient.post CONFIG["slack_url"], {
      payload:
      { text: message, icon_emoji: ":fire:", username: "GPlay Crashes", channel: "#{CONFIG["channel"]}" }.to_json
    },
    content_type: :json,
    accept: :json
    
  end
end

class Review
  def self.collection
    @collection ||= []
  end

  def self.send_reviews_from_date(date)
    message = collection.select do |r|
	r.crashdate > date
    end.sort_by do |r|
	r.crashdate
    end.map do |r|
	r.build_message
    end.join("\n")

    if message != ""
      Slack.notify(message)
    else
      print "No new crashes\n"
    end
  end

    attr_accessor :crashdate, :device, :osversion, :appversion, :appversioncode, :message, :crashlib, :crash, :url

  def initialize data = {}
  
    @crashdate = DateTime.parse(data[:crashdate].encode("utf-8"))
    @device = data[:device] ? data[:device].to_s.encode("utf-8") : nil
    @osversion = data[:osversion] ? data[:osversion].to_s.encode("utf-8") : nil
    @appversion = data[:appversion] ? data[:appversion].to_s.encode("utf-8") : nil
    @appversioncode = data[:appversioncode] ? data[:appversioncode].to_s.encode("utf-8") : nil
    @message = data[:message] ? data[:message].to_s.encode("utf-8") : nil
    @crashlib = data[:crashlib] ? data[:crashlib].to_s.encode("utf-8") : nil
    @crash = data[:crash] ? data[:crash].to_s.encode("utf-8") : nil
    @url = data[:url] ? data[:url].to_s.encode("utf-8") : nil

  end

  def build_message
    
    date = "Date: #{crashdate.strftime("%d.%m.%Y at %I:%M%p")}"
    
    if crashlib
	acrash = "#{crash}".gsub(", /","\n/")
    end
    
    [
	"\n\n#{date}",
	"OS Version: #{osversion}, Device: #{device}",
	"App Version: #{appversion}, App Versioncode: #{appversioncode}",
	"Message: #{message}",
	"<#{url}|Crash url>",
	"Stack: \n#{acrash}"
    ].join("\n")

  end
  
end

CSV.foreach(csv_file_name, encoding: 'bom|utf-16le', headers: true) do |row|

    Review.collection << Review.new({
    crashdate: row[1],
    device: row[3],
    osversion: row[4],
    appversion: row[5],
    appversioncode: row[6],
    message: row[8],
    crashlib: row[13],
    crash: row[14],
    url: row[15],
    })

end

Review.send_reviews_from_date(date)
