namespace :daycares do
  desc "Import the official BC childcare directory"
  task import_bc: :environment do
    result = BcDaycareImporter.call
    puts "BC daycare import complete: created=#{result.created} updated=#{result.updated} rejected=#{result.rejected}"
  rescue BcDaycareImporter::DownloadError,
    BcDaycareImporter::InvalidDownload,
    BcDaycareImporter::InvalidConfiguration => error
    abort "BC daycare import aborted before changing data: #{error.message}"
  end
end
