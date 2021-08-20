import Vapor

func routes(_ app: Application) throws {
  try CLIChat.routes(app)
  try ChatUI.routes(app)
  try Stocked.routes(app)
  try Downloader.routes(app)
  try Hello.routes(app)
}
