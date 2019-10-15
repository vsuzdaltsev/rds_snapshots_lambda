# frozen_string_literal: true

# String class extension to colorize some output
class String
  def red
    "\e[31m#{self}\e[0m"
  end

  def green
    "\e[32m#{self}\e[0m"
  end
end
