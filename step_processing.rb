require_relative 'printers'
require 'selenium-webdriver'
require 'yaml'
require 'csv'
require 'pry'


Selenium::WebDriver::Chrome::Service.driver_path= "C:/selenium/chromedriver.exe"
capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(accept_insecure_certs: true)
@@driver = Selenium::WebDriver.for(:chrome, desired_capabilities: capabilities)
@@wait = Selenium::WebDriver::Wait.new(timeout: 20)
@@driver.manage.timeouts.page_load = 20

class Reporting
  def initialize
    puts @@driver
  end

  def element_by_id(id)
    @@driver.find_element(id: id)
  end

  def model_check(model_ip)
    begin
    @@driver.get("http://#{model_ip}")
    rescue
    end

    begin
    @model_name = @@driver.find_element(id: 'productName').text.split(' ').last if @@driver.find_element(id: 'productName').displayed?
    puts "model: #{@model_name}"
    rescue
    end

    begin
    @model_name = @@driver.find_elements(class: 'webui-globalNavigation-productName').map(&:text).first.split(' ')[2] if @@driver.find_element(id: 'mainPage').displayed?
    puts "model: #{@model_name}"
    rescue
    end

    return eval("#{@model_name}.new") if @model_name
  end
end

class AltaLink
  attr_reader :model_name

    def initialize
      puts 'altalink call'
      @model_name = self.class.name
    end

    def logging_in
      @@wait.until { @@driver.find_element(id: 'frmwebUsername').displayed? }
      @@driver.find_element(id: 'frmwebUsername').send_keys('admin')
      @@driver.find_element(id: 'frmwebPassword').send_keys(YAML.load_file('data.yaml')['password'])
       @@driver.find_element(id: 'loginBtn').click 
       sleep(3)
      @@wait.until { @@driver.find_element(id: 'productName').displayed? }
    end
      
    def pick_notification
      a = @@driver.find_elements(:css, "table#tableNotifications td").map(&:text)
      b = a.select { |obj| !obj.empty? }
      c = b.select { |obj| !obj.match(/^The machine is in Sleep/) }
      d = c.select { |obj| !obj.match(/^Tray/) }
      @notifications = d.select { |obj| !obj.match(/^[0-9]/) }
      return @notifications
    end

    def toner_levels
    end

    def serial_number
      @@driver.find_element(id: 'device-name').text.split('_')[1] ||= @@driver.find_elements(class:'rightColumnAlign')[3].text
    end


    def create_report
        logging_in  
        pick_notification
        toner_levels
        serial_number
    end
end

class B8045 < AltaLink

  def initialize
    super
  end

  def toner_levels
    @toner_levels = @@driver.find_elements(class: 'supply').map(&:text)[0]
  end
end

class C8045 < AltaLink
  def initialize
    super
    @model_name = 'C8045'
  end

  def toner_levels
    @toner = @@driver.find_elements(class: 'levelIndicatorPercentage').map(&:text)
    @cyan, @magenta, @yellow, @black = @toner[0], @toner[1], @toner[2], @toner[3]
    @toner_levels = "#{@cyan}/#{@magenta}/#{@yellow}/#{@black}"
    return @toner_levels
  end

end

class VersaLink
  attr_reader :model_name

  def initialize
    puts 'versalink call'
    @model_name = self.class.name
  end

  def logging_in
    begin
    @@wait.until { @@driver.find_element(id: 'mainPage').displayed? }
      sleep(7)
      if @@driver.find_element(id: 'loginName').displayed?
        @@driver.find_element(id: 'loginName').send_keys('admin')
        @@driver.find_element(id: 'loginPsw').send_keys(YAML.load_file('data.yaml')['password'])
        @@driver.find_element(id: 'loginButton').click
        sleep(3)
      end
    rescue 
    end
  end 

  def pick_notification
  end

  def toner_levels
  end

  def serial_number
    @@driver.find_element(id: 'openDeviceInfoDetailsModalWindow').click
    @@driver.find_elements(class: 'xux-labelableBox-content').map(&:text)[12]
  end
end

class B400DN < VersaLink
  def initialize 
    super
  end

  def pick_notification
    @notifications = @@driver.find_elements(class: 'xux-labelableBox-label').map(&:text)[5] 
  end

  def toner_levels
    @toner_levels = @@driver.find_elements(class: 'webui-home-media-text').map(&:text)[3]
  end

  # def serial_number
  # end
end

class B405DN < VersaLink
  def initialize 
    super
  end

  def pick_notification
    sleep(3)
    @notifications = @@driver.find_elements(class: 'xux-labelableBox-label').map(&:text)[-2] 
  end

  def toner_levels
    sleep(3)
    @toner_levels = @@driver.find_elements(class: 'webui-home-media-text').map(&:text).last
    puts "toner levels: #{@toner_levels}"
    return @toner_levels
  end

  # def serial_number
  # end
end

class C405DN < VersaLink
  def initialize 
    super
  end

  def pick_notification
    @notifications = @@driver.find_elements(class: 'xux-labelableBox-label').map(&:text)[6] 
  end

  def toner_levels
    @toner = @@driver.find_elements(class: 'webui-home-media-text').map(&:text)
    @toner_levels = "#{@toner[3]}/#{@toner[5]}/#{@toner[7]}/#{@toner[9]}"
  end

  def serial_number
    @driver.find_elements(class: 'xux-textOmittable-false').map(&:text)[6]
  end
end

class CSV_operation
  
  def initialize
  end

  def create_report
    time = Time.now.strftime("%Y-%m-%d_%H_%M_%S")
    CSV.open("reports/step_report_#{time}.csv",'a+') do |csv|
      csv << %w(ip model cmyk serial  notifications alias)
      puts 'create a csv file'

      PRINTERS.each do |el|
        @notifications = ""
        @toner_levels = ""
        @model_name = ""
        @serial = ''
        @ip = el[:ip]
        @alias = el[:alias]

        puts "Opening #{el[:ip]}"
        printer = Reporting.new.model_check(el[:ip])
        begin
        printer.logging_in
        puts 'logged in'
        rescue
          puts 'problem while logging in'
        end

        @model_name = printer.model_name rescue 'unknown'
        puts 'model name --done'
        @notifications = printer.pick_notification rescue 'error'
        puts 'notifications --done'
        @toner_levels = printer.toner_levels rescue 'error'
        puts 'toner levels --done'
        @serial = printer.serial_number rescue 'error'
        puts 'serial number --done'

        csv << ["#{@ip}", "#{@model_name}", "#{@toner_levels}", "#{@serial}", "#{@notifications}", "#{@alias}"]
      end
    end
  end
end

CSV_operation.new.create_report