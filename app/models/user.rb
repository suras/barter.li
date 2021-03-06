class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  before_save :change_lowercase
  before_update :geocode_address
  devise :database_authenticatable, :registerable, :omniauthable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
  has_many :books
  has_many :settings
  has_many :email_tracks
  has_many :wish_lists
  has_many :alerts
  has_many :authentications
  has_many :posts
  has_many :groups
  

  def change_lowercase
    self.country.downcase! if self.country
    self.state.downcase! if self.state
    self.city.downcase! if self.city
    self.street.downcase! if self.street
    self.locality.downcase! if self.locality
  end

  # foursquare api to get users near by locations
  def near_by_hangouts
    client = Foursquare2::Client.new(:client_id => ENV["FOURSQUARE_CLIENT_ID"], :client_secret => ENV["FOURSQUARE_CLIENT_SECRET"])
    if(self.latitude.present? && self.longitude.present?)
      return client.search_venues(:ll => self.latitude.to_s+','+self.longitude.to_s, :query => 'coffee')
    else
      return " "
    end
  end

  # send wish list mail for users
  # attributs book model object, wishlist model object
  def mail_wish_list(book, wishlist)
    if self.can_send_mail
      Notifier.wish_list_book(self, book).deliver
      save_email_track(Code[:wish_list_book])
    end
  end
  
  # checks whether email can be sent based on user settings 
  # for no of emails and duration
  def can_send_mail
    month_emails = self.mails_by_month(Time.now.month)
    if(month_emails.count < self.setting_email_count_month )
      return true if month_emails.count == 0
      last_email_sent = month_emails.first.created_at
      (mail_duration(last_email_sent) >= self.setting_email_duration) ? true : false
    else
      false
    end
  end

  def setting_email_duration
    duration = self.settings.find_by(:name => "email_duration")
    duration = duration.present? ? duration.value.to_i : DefaultSetting.email_duration.to_i
  end

  def setting_email_count_month
    email_per_month = self.settings.find_by(:name => "email_per_month")
    email_per_month = email_per_month.present? ? email_per_month.value.to_i : DefaultSetting.email_per_month.to_i
  end
  
  # attributes
  # time_date :time object ex: time.now
  def mail_duration(time_date)
    duration_difference = Time.now.to_i - time_date.to_i
  end
  
  # attributes
  # month :an integer representation of month ex: 1 or 01
  def mails_by_month(month)
    month_emails = self.email_tracks.where('extract(month from created_at) = ?', month).order(created_at: :desc)
  end
  
  # attributes
  # sent_for :a code to identify why the email is sent
  def save_email_track(sent_for)
    email_track = self.email_tracks.new()
    email_track.sent_for = sent_for
    email_track.save
  end
 
  # attributes
  # obj :object to create alert for, alert_type :type of alert
  def create_alert(obj, alert_type)
    alert = self.alerts.new
    alert.thing = obj
    alert.reason_type = alert_type
    alert.save
  end
  
  # address to display on maps
  def map_address
    map_address = [self.country.to_s, self.city.to_s, self.locality.to_s]
    map_address.join(",")
  end

  def apply_omniauth(omni)
    self.authentications.create(:provider => omni['provider'], :uid => omni['uid'],
    :token => omni['credentials'].token, :token_secret => omni['credentials'].secret)
  end

  # geocode address only on update and fields have changed
  def geocode_address
    return unless street_changed? || city_changed? || country_changed? || locality_changed? || state_changed?
    coords = Geocoder.coordinates(self.street.to_s+","+self.locality.to_s+','+self.city.to_s+','+self.country.to_s)
    if coords.kind_of?(Array)
      self.latitude = coords[0];
      self.longitude = coords[1];
    end
  end

end
