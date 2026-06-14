class ServiceResult
  attr_reader :error, :payload

  def self.success(payload = nil)
    new(success: true, payload: payload)
  end

  def self.failure(error, message = nil)
    new(success: false, error: error, message: message)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def error_message
    @message || @error.to_s
  end

  private

  def initialize(success:, payload: nil, error: nil, message: nil)
    @success = success
    @payload = payload
    @error = error
    @message = message
  end
end
