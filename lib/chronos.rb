# Chronos interface object
require 'json'
require 'net/http'
require 'uri'

require 'config'

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

module Orch
  class Chronos
    def initialize(options)
    end

    def deploy(url, json_payload)
      if url.nil?
        exit_with_msg "chronos_url not defined"
      end

      uri = URI(url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      path = nil
      path = "/scheduler/iso8601" unless json_payload["schedule"].nil?
      path = "/scheduler/dependency" unless json_payload["parents"].nil?
      if path.nil?
        exit_with_msg "neither schedule nor parents fields defined for Chronos job"
      end

      http = Net::HTTP.new(uri.host, uri.port)
      begin
        response = http.post(path, json_payload, json_headers)
      rescue *HTTP_ERRORS => error
        http_fault(error)
      end

      if response.code != 204.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      return response
    end

    def delete(url, name)
      if url.nil?
        exit_with_msg "chronos_url not defined"
      end

      uri = URI(url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      # curl -L -X DELETE chronos-node:8080/scheduler/job/request_event_counter_hourly
      http = Net::HTTP.new(uri.host, uri.port)
      begin
        response = http.delete("/scheduler/job/#{name}", json_headers)
      rescue *HTTP_ERRORS => error
        http_fault(error)
      end

      if response.code != 204.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      return response
    end

    def verify(url, json_payload)
      if url.nil?
        puts "no chronos_url - can not verify with server"
        return
      end

      spec = Hashie::Mash.new(JSON.parse(json_payload))

      uri = URI(url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      http = Net::HTTP.new(uri.host, uri.port)
      begin
        response = http.get("/scheduler/jobs/search?name=#{spec.name}", json_headers)
      rescue *HTTP_ERRORS => error
        http_fault(error)
      end

      if response.code != 200.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
        foundDiffs = true 
      end

      array = JSON.parse(response.body).map { |hash| Hashie::Mash.new(hash) }

      # Chronos search API could return more than one item - make sure we find the exact match
      jobFound = false
      array.each do |job|
        if job.name == spec.name
          jobFound = true
          foundDiffs = find_diffs(spec, job)
        end
      end
      
      if !jobFound
        puts "job \"#{spec.name}\" not currently deployed"
        foundDiffs = true 
      end

      return foundDiffs
    end

    def find_diffs(spec, job)
      foundDiff = false

      spec.each_key do |key|
        if spec[key].is_a?(Hash)
          if find_diffs(spec[key], job[key]) == true
            foundDiff = true
          end
          next
        end
        if spec[key].is_a?(Array)
          if spec[key].length != job[key].length
            printf("difference for field: %s - length of array is different\n", key)
            printf("    spec:   %s\n", spec[key].to_json)
            printf("    server: %s\n", job[key].to_json)
            foundDiff = true
            next
          end
          # TODO: not sure how to compare arrays
        end
        specVal = spec[key]
        jobVal = job[key]
        if spec[key].to_s.numeric?
          specVal = Float(spec[key])
          jobVal = Float(job[key])
        else
          specVal = spec[key]
          jobVal = job[key]
        end
        # Chronos changes the case of the Docker argument for some reason
        if key == "type"
          specVal = specVal.upcase
          jobVal = jobVal.upcase
        end
        if specVal != jobVal
          if foundDiff == false
            puts "Differences found in job"
          end
          printf("difference for field: %s\n", key)
          printf("    spec:   %s\n", specVal)
          printf("    server: %s\n", jobVal)
          foundDiff = true
        end
      end

      return foundDiff
    end
  end
end