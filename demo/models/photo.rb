require "./config/sequel"
require "./uploaders/image_uploader"

class Photo < Sequel::Model
  include ImageUploader::Attachment.new(:image)
end
