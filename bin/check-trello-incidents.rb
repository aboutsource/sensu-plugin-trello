#!/usr/bin/env ruby
#
# Check for new incidents in Trello
#
# DESCRIPTION:
#   Checks for cards in a trello list. If cards are present, the check returns 
#   CRITICAL, containing name and date of last activity of card. When more 
#   than one card is present, all card names and dates are returned with ';' 
#   delimiter.
#
# CONFIGURATION:
#   Configuration of API key and API token should be done through the sensu 
#   settings file located in /etc/sensu/conf.d/. 
#      
#   'api_key' and 'api_token' can be obtained from Trello
#   (https://trello.com/app-key). 'list' can be obtained by adding .json 
#   to a card in the browser in the list that should be monitored and search 
#   for 'idList' in the JSON-output. Note that in a production environment, 
#   api_key and api_token must be specified in the sensu settings rather than
#   through CLI parameters.
#
# OUTPUT:
#   plain text
#
#
# USAGE:
#   Check if a specific trello list is empty or contains cards
#      ./check-trello-incidents.rb -k 123456789012 -t 1234567890121234567890 \
#         -l 1234567890 
# 


require 'sensu-plugin/check/cli'
require 'sensu-plugin/utils'
require 'json'
require 'yaml'
require 'net/http'

class CheckTrelloIncidents < Sensu::Plugin::Check::CLI
  include Sensu::Plugin::Utils
  
  option :host,
    description: 'Trello host address',
    short: '-h HOST',
    long: '--host HOST',
    default: 'api.trello.com'

  option :port,
    description: 'Trello port',
    short: '-p PORT',
    long: '--port PORT',
    default: '443'

  option :list,
    description: 'Trello list to check',
    short: '-l LIST',
    long: '--list LIST'

  option :api_key,
    description: 'Trello API key',
    short: '-k KEY',
    long: '--api-key KEY'

  option :api_token,
    description: 'Trello API token',
    short: '-t TOKEN',
    long: '--api-token TOKEN'

  def run
    if config[:list].match(/\A[a-z0-9]*\z/).nil?
      raise 'Invalid value for list parameter: ' + config[:list]
    end 

    host = config[:host]
    port = config[:port]
    key =  config[:api_key] || settings['trello_incidents']['api']['key']
    token = config[:api_token] || settings['trello_incidents']['api']['token']
    list = config[:list]

    begin
      Timeout.timeout(10) do
        check_list(host, port, key, token, list)
      end
    rescue Timeout::Error
      unknown 'Connection timed out'
    rescue => e
      unknown 'Connection error: #{e.message}'
    end
       
  end

  def check_list(host, port, key, token, list)
    path = '/1/lists/' + list + '/cards'
    
    uri = URI.parse('https://' + host + ':' + port + path)
    params = { :key => key, :token => token }
    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)
    
    unless res.code =~ /^2/
      unknown res.code
    end
    
    incidents = JSON.parse(res.body)

    if(incidents.empty?)
      ok 'No new incidents'
    else
      msgs = []
      incidents.each do |incident|
        msgs.push(incident['name'] + ' ' + incident['dateLastActivity'])
      end
      msg = msgs.join(';')
      
      critical msg
    end
  end
end