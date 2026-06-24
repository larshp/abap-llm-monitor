const { createReadStream } = require("node:fs");
const { access, stat } = require("node:fs/promises");
const { createServer } = require("node:http");
const { extname, join, normalize, resolve, sep } = require("node:path");

const publicDir = resolve(__dirname, "public");
const port = Number.parseInt(process.env.PORT ?? "3000", 10);
const host = process.env.HOST ?? "127.0.0.1";

const contentTypes = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".ico", "image/x-icon"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".txt", "text/plain; charset=utf-8"],
  [".webp", "image/webp"]
]);

function resolvePublicPath(requestUrl) {
  const url = new URL(requestUrl, `http://${host}:${port}`);
  const decodedPath = decodeURIComponent(url.pathname);
  const normalizedPath = normalize(decodedPath).replace(/^(\.\.[/\\])+/, "");
  const filePath = resolve(publicDir, `.${sep}${normalizedPath}`);

  if (!filePath.startsWith(`${publicDir}${sep}`) && filePath !== publicDir) {
    return null;
  }

  return filePath;
}

async function findStaticFile(requestUrl) {
  const filePath = resolvePublicPath(requestUrl);

  if (!filePath) {
    return null;
  }

  try {
    const fileStat = await stat(filePath);

    if (fileStat.isDirectory()) {
      const indexPath = join(filePath, "index.html");
      await access(indexPath);
      return indexPath;
    }

    if (fileStat.isFile()) {
      return filePath;
    }
  } catch {
    return null;
  }

  return null;
}

const server = createServer(async (request, response) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    response.writeHead(405, {
      Allow: "GET, HEAD",
      "Content-Type": "text/plain; charset=utf-8"
    });
    response.end("Method Not Allowed");
    return;
  }

  const filePath = await findStaticFile(request.url ?? "/");

  if (!filePath) {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Not Found");
    return;
  }

  response.writeHead(200, {
    "Cache-Control": "no-cache",
    "Content-Type": contentTypes.get(extname(filePath)) ?? "application/octet-stream"
  });

  if (request.method === "HEAD") {
    response.end();
    return;
  }

  createReadStream(filePath).pipe(response);
});

server.listen(port, host, () => {
  console.log(`Serving static files from ${publicDir}`);
  console.log(`Frontend available at http://${host}:${port}`);
});

let isShuttingDown = false;

process.on("SIGINT", () => {
  if (isShuttingDown) {
    return;
  }

  isShuttingDown = true;
  console.log("\nStopping frontend server...");

  server.close((error) => {
    if (error) {
      console.error(error);
      process.exit(1);
    }

    console.log("Frontend server stopped.");
    process.exit(0);
  });
});
