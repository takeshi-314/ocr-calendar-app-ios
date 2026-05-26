const { onCall } = require("firebase-functions/v2/https");
const { Storage } = require("@google-cloud/storage");
const { DocumentProcessorServiceClient } = require("@google-cloud/documentai").v1;

const storage = new Storage();

const PROJECT_ID = "calendar-ocr-app-af471";
const LOCATION = "asia-northeast1";
const PROCESSOR_ID = "95367db6bd21793b";exports.helloFromFunctions = onCall(
  {
    region: "asia-northeast1",
    invoker: "public",
  },
  async (request) => {
    const name = request.data?.name || "user";

    return {
      message: `hello from functions, ${name}`,
      receivedAt: new Date().toISOString(),
    };
  }
);

exports.ocrFromStorage = onCall(
  {
    region: "asia-northeast1",
    invoker: "public",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (request) => {
    const path = request.data?.path;

    if (!path) {
      throw new Error("path がありません。Firebase Storage上のファイルパスを送ってください。");
    }

    const bucketName = `${PROJECT_ID}.appspot.com`;

    const [fileBuffer] = await storage
      .bucket(bucketName)
      .file(path)
      .download();

    const client = new DocumentProcessorServiceClient({
      apiEndpoint: `${LOCATION}-documentai.googleapis.com`,
    });

    const name = client.processorPath(PROJECT_ID, LOCATION, PROCESSOR_ID);

    const [result] = await client.processDocument({
      name,
      rawDocument: {
        content: fileBuffer.toString("base64"),
        mimeType: "image/jpeg",
      },
    });

    const text = result.document?.text || "";

    return {
      text,
      path,
      length: text.length,
    };
  }
);
