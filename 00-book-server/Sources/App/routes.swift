import Vapor

func routes(_ app: Application) throws {
  try Hello.routes(app)
  try Stocked.routes(app)
  try SuperStorage.routes(app)
  try Blabber.routes(app)
  try Clipper.routes(app)
}
