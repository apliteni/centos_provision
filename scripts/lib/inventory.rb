class Inventory
  attr_reader :values

  INVENTORY_FILE = '.keitaro/installer_config'
  LINES_DIVIDER = "\n"
  VALUES_DIVIDER = '='
  LOG_PRE_INVENTORY_LINE = 'Writing inventory file: STARTED'
  LOG_POST_INVENTORY_LINE = 'Writing inventory file: DONE'

  def initialize(values: {})
    self.values = values
  end

  def self.read_from_log(log_content)
    log_lines_match = log_content.to_s.match(/#{LOG_PRE_INVENTORY_LINE}(.*)#{LOG_POST_INVENTORY_LINE}/m)
    log_lines = log_lines_match&.captures&.first.to_s
    Inventory.new(values: parse(log_lines.gsub(/^ +/, '')))
  end

  def self.parse(content)
    content
      .split(LINES_DIVIDER)
      .grep(/#{VALUES_DIVIDER}/)
      .map { |line| k, v = line.split(VALUES_DIVIDER); [k, v] }
      .to_h
  end

  def self.write(values)
    strings = values
                .map { |array| array.join(VALUES_DIVIDER) }
                .push('')
    Dir.mkdir("#{File.dirname(Inventory::INVENTORY_FILE)}")
    IO.write(INVENTORY_FILE, strings.join(LINES_DIVIDER))
  end

  def values=(values)
    @values = values.map { |k, v| [k.to_sym, v] }.to_h
  end
end

