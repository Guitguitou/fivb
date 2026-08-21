#!/usr/bin/env ruby
# Suivi de la paire Ferry/Ferry (MON) sur le Beach Pro Tour - Futures Modena 2026
# Verifie Reserve / Qualification / Main Draw et notifie par WhatsApp (CallMeBot)
# en cas de changement (nouvelle position, ou changement de tableau).

require "net/http"
require "uri"
require "nokogiri"
require "json"
require "time"

TEAM_KEYWORDS = ["Pascal Ferry", "Vincent Ferry"].freeze

DRAWS = {
  "reserve" => "https://en.volleyballworld.com/beachvolleyball/competitions/beach-pro-tour/2026/futures/modena-ita/teams/men/reserve",
  "qualification" => "https://en.volleyballworld.com/beachvolleyball/competitions/beach-pro-tour/2026/futures/modena-ita/teams/men/qualification",
  "main_draw" => "https://en.volleyballworld.com/beachvolleyball/competitions/beach-pro-tour/2026/futures/modena-ita/teams/men/main-draw",
}.freeze

DRAW_LABELS = {
  "reserve" => "Reserve",
  "qualification" => "Qualification",
  "main_draw" => "Tableau Principal",
}.freeze

STATE_FILE = File.join(__dir__, "state.json")

def fetch_html(url, redirects_left = 3)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 15
  http.read_timeout = 15

  request = Net::HTTP::Get.new(uri)
  request["User-Agent"] = "Mozilla/5.0 (compatible; FerryWatcher/1.0; +personal-use-script)"

  response = http.request(request)

  case response
  when Net::HTTPRedirection
    raise "Trop de redirections pour #{url}" if redirects_left.zero?

    location = response["location"]
    location = URI.join(url, location).to_s unless location.start_with?("http")
    return fetch_html(location, redirects_left - 1)
  when Net::HTTPSuccess
    response.body
  else
    raise "HTTP #{response.code} pour #{url}"
  end
end

def find_team_position(html)
  doc = Nokogiri::HTML(html)

  doc.css("table tr").each do |row|
    text = row.text
    next unless TEAM_KEYWORDS.any? { |kw| text.include?(kw) }

    cells = row.css("td")
    next if cells.empty?

    return cells[0].text.strip
  end

  nil
end

def current_status
  any_success = false

  DRAWS.each do |draw_name, url|
    html = fetch_html(url)
    any_success = true
    position = find_team_position(html)
    return { "draw" => draw_name, "position" => position, "ok" => true } if position
  rescue => e
    warn "Erreur en verifiant #{draw_name} (#{url}): #{e.message}"
  end

  { "draw" => nil, "position" => nil, "ok" => any_success }
end

def load_previous_state
  return { "state" => {}, "first_run" => true } unless File.exist?(STATE_FILE)

  content = File.read(STATE_FILE).strip
  return { "state" => {}, "first_run" => true } if content.empty?

  { "state" => JSON.parse(content), "first_run" => false }
rescue JSON::ParserError
  { "state" => {}, "first_run" => true }
end

def save_state(state)
  File.write(STATE_FILE, JSON.pretty_generate(state))
end

def send_whatsapp(message)
  phone = ENV.fetch("CALLMEBOT_PHONE")
  apikey = ENV.fetch("CALLMEBOT_APIKEY")

  uri = URI("https://api.callmebot.com/whatsapp.php")
  uri.query = URI.encode_www_form(phone: phone, apikey: apikey, text: message)

  response = Net::HTTP.get_response(uri)
  puts "CallMeBot -> #{response.code} #{response.body}"
end

def build_message(previous, current)
  if current["draw"].nil?
    return "⚠️ Ferry/Ferry (MON) n'apparaissent plus dans Reserve, Qualification ni Main Draw " \
           "du tournoi Modena. A verifier manuellement !"
  end

  draw_label = DRAW_LABELS.fetch(current["draw"], current["draw"])

  if previous["draw"].nil?
    "🏐 Ferry/Ferry (MON) : #{draw_label}, position #{current['position']}."
  elsif previous["draw"] != current["draw"]
    previous_label = DRAW_LABELS.fetch(previous["draw"], previous["draw"])
    "🏐 Ferry/Ferry (MON) sont passes de #{previous_label} (##{previous['position']}) " \
      "a #{draw_label} (##{current['position']}) !"
  else
    "🏐 Ferry/Ferry (MON) ont bouge en #{draw_label} : " \
      "position ##{previous['position']} -> ##{current['position']}"
  end
end

previous_data = load_previous_state
previous = previous_data["state"]
first_run = previous_data["first_run"]

current = current_status

puts "Etat precedent : #{previous.inspect}"
puts "Etat actuel    : #{current.inspect}"

unless current["ok"]
  puts "Impossible de recuperer un seul des 3 tableaux (probleme reseau/site) : on ne compare pas cette fois-ci."
  exit 0
end

changed = previous["draw"] != current["draw"] || previous["position"] != current["position"]

if changed
  unless first_run
    message = build_message(previous, current)
    send_whatsapp(message)
    puts "Changement detecte -> notification envoyee : #{message}"
  else
    puts "Premier lancement : etat initial enregistre, pas de notification."
  end

  save_state(current.merge("updated_at" => Time.now.utc.iso8601))
else
  puts "Aucun changement."
end
