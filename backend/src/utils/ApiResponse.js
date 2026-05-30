export class ApiResponse {
  static ok(res, data = {}, status = 200) {
    res.status(status).json(data);
  }

  static created(res, data = {}) {
    this.ok(res, data, 201);
  }

  static noContent(res) {
    res.status(204).end();
  }
}
