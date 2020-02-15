class FAError < StandardError
  attr_accessor :url

  def initialize(url)
    super('Error accessing FA')
    @url = url
  end
end

class FAFormError < FAError
  def initialize(url, field = nil)
    super(url)
    @field = field
  end

  def to_s
    if @field
      "You must provide a value for the field '#{@field}'."
    else
      "There was an unknown error submitting to FA."
    end
  end
end

class FAOffsetError < FAError
  def initialize(url, message)
    super(url)
    @message = message
  end

  def to_s
    @message
  end
end

class FASearchError < FAError
  def initialize(key, value, url)
    super(url)
    @key = key
    @value = value
  end

  def to_s
    field = @key.to_s
    multiple = SEARCH_MULTIPLE.include?(@key) ? 'zero or more' : 'one'
    options = SEARCH_OPTIONS[@key].join(', ')
    "The search field #{field} must contain #{multiple} of: #{options}.  You provided: #{@value}"
  end
end

class FAStatusError < FAError
  def initialize(url, status)
    super(url)
    @status = status
  end

  def to_s
    "FA returned a status of '#{@status}' while trying to access #{@url}."
  end
end

class FASystemError < FAError
  def initialize(url)
    super(url)
  end

  def to_s
    "FA returned a system error page when trying to access #{@url}."
  end
end

class FAStyleError < FAError
  def initialize(url)
    super(url)
  end

  def to_s
    "FA is not currently set to classic theme. Unfortunately this API currently only works if the authenticated
account is using classic theme. Please change your style to classic and try again."
  end
end

class FALoginError < FAError
  def initialize(url)
    super(url)
  end

  def to_s
    "Unable to log into FA to access #{@url}."
  end
end

class FALoginCookieError < FAError
  def initialize(message)
    super(nil)
    @message = message
  end

  def to_s
    @message
  end
end

class CacheError < FAError
  def initialize(message)
    super(nil)
    @message = message
  end

  def to_s
    @message
  end
end

class FAInputError < FAError
  def initialize(message)
    super(nil)
    @message = message
  end

  def to_s
    @message
  end
end
