module Scaler
  class BoshClient
    def initialize(endpoint_uri, user, password, disable_verify_certification = false)
      @endpoint_uri = endpoint_uri
      @user = user
      @password = password
      @disable_verify_certification = disable_verify_certification
    end

    def self.load(options)
      new(
        options['endpoint_uri'],
        options['user'],
        options['password'],
        options['disable_verify_certification'] || false
      )
    end

    def fetch_deployment_manifest(name)
      request = Net::HTTP::Get.new("/deployments/#{name}")
      response = send(request)
      unless response.code == '200'
        fail "Failed to fetch deployment manifest from Director (HTTP CODE: #{response.code})"
      end

      Yajl::Parser.parse(response.body)['manifest']
    end

    def deploy(manifest)
      request = Net::HTTP::Post.new('/deployments')
      request['Content-Type'] = 'text/yaml'
      request.body = manifest
      response = send(request)
      unless response.code == '302'
        fail "Failed to deploy manifest (HTTP CODE: #{response.code})"
      end

      create_task_from_response(response)
    end

    def processing_deployment?
      request = Net::HTTP::Get.new('/tasks?state=processing')
      response = send(request)
      unless response.code == '200'
        fail "Failed to fetch tasks from Director (HTTP CODE: #{response.code})"
      end

      json = Yajl::Parser.parse(response.body)
      deployment_task = json
        .find { |task| task['description'].match(/(create|delete|snapshot) deployment/) }
      !deployment_task.nil?
    end

    def fetch_vitals(deployment_name)
      request = Net::HTTP::Get.new("/deployments/#{deployment_name}/vms?format=full")
      response = send(request)
      unless response.code == '302'
        fail "Failed to fetch VMS vitals (HTTP CODE: #{response.code})"
      end

      create_task_from_response(response)
    end

    def fetch_deployments
      request = Net::HTTP::Get.new('/deployments')
      response = send(request)
      unless response.code == '200'
        fail "Failed to fetch deployments from Director (HTTP CODE: #{response.code})"
      end

      Yajl::Parser.parse(response.body)
    end

    def fetch_agents(deployment_name)
      request = Net::HTTP::Get.new("/deployments/#{deployment_name}/vms")
      response = send(request)
      unless response.code == '200'
        fail "Failed to fetch Agent information from Director (HTTP CODE: #{response.code})"
      end

      Yajl::Parser.parse(response.body)
    end

    def fetch_task_state(task_id)
      request = Net::HTTP::Get.new("/tasks/#{task_id}")
      response = send(request)
      unless response.code == '200'
        fail "Failed to fetch task from Director (HTTP CODE: #{response.code})"
      end

      Yajl::Parser.parse(response.body)['state']
    end

    def fetch_task_result(task_id)
      request = Net::HTTP::Get.new("/tasks/#{task_id}/output?type=result")
      response = send(request)
      unless response.code == '200'
        fail "Failed to fetch task result from Director (HTTP CODE: #{response.code})"
      end
      response.body
    end

    def send(request)
      request.basic_auth(@user, @password)

      endpoint_uri = URI.parse(@endpoint_uri)
      http = Net::HTTP.new(endpoint_uri.host, endpoint_uri.port)
      http.use_ssl = (endpoint_uri.scheme == 'https')
      if @disable_verify_certification
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      http.request(request)
    end

    def extract_task_id(response)
      matches = response.header['Location'].match(%r{/tasks/(\d+)$})
      unless matches
        fail 'Filed to extract Job ID from response'
      end
      matches[1]
    end

    def create_task(id)
      Task.new(id, self)
    end

    def create_task_from_response(response)
      create_task(extract_task_id(response))
    end
  end
end
