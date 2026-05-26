const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { Storage } = require("@google-cloud/storage");
const { DocumentProcessorServiceClient } = require("@google-cloud/documentai").v1;
const { GoogleGenAI, Type } = require("@google/genai");

const storage = new Storage();

const PROJECT_ID = "calendar-ocr-app-af471";
const LOCATION = "asia-southeast1";
const PROCESSOR_ID = "95367db6bd21793b";
const GEMINI_LOCATION = "global";
const GEMINI_MODEL = "gemini-2.5-flash";

exports.helloFromFunctions = onCall(
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
    try {
      const path = request.data?.path;

      if (!path) {
        throw new HttpsError(
          "invalid-argument",
          "path がありません。Firebase Storage上のファイルパスを送ってください。"
        );
      }
      const mimeType = request.data?.mimeType || "image/jpeg";

      const bucketName = "calendar-ocr-app-af471.firebasestorage.app";

      console.log("OCR start");
      console.log("path:", path);
      console.log("bucketName:", bucketName);
      console.log("mimeType:", mimeType);

      const [fileBuffer] = await storage
        .bucket(bucketName)
        .file(path)
        .download();

      console.log("downloaded bytes:", fileBuffer.length);

      const client = new DocumentProcessorServiceClient({
        apiEndpoint: `${LOCATION}-documentai.googleapis.com`,
      });

      const name = client.processorPath(PROJECT_ID, LOCATION, PROCESSOR_ID);

      console.log("processor name:", name);

      const [result] = await client.processDocument({
        name,
          rawDocument: {
            content: fileBuffer.toString("base64"),
            mimeType,
          },
      });

      const text = result.document?.text || "";

      console.log("ocr text length:", text.length);

      return {
        text,
        path,
        length: text.length,
      };
    } catch (error) {
      console.error("OCR ERROR:", error);

      throw new HttpsError(
        "internal",
        error.message || "OCR処理中に不明なエラーが発生しました。"
      );
    }
  }
);

exports.extractScheduleFromText = onCall(
  {
    region: "asia-northeast1",
    invoker: "public",
    timeoutSeconds: 120,
    memory: "1GiB",
  },
  async (request) => {
    try {
      const ocrText = request.data?.text;

      if (!ocrText) {
        throw new HttpsError(
          "invalid-argument",
          "text がありません。OCRで読み取った文字列を送ってください。"
        );
      }

      const ai = new GoogleGenAI({
        vertexai: true,
        project: PROJECT_ID,
        location: GEMINI_LOCATION,
      });

      const prompt = `
あなたは予定情報を抽出するアシスタントです。
以下のOCR結果から、カレンダー登録に必要な情報を抽出してください。

重要ルール:
- 不明な項目は null にしてください。
- 日付は YYYY-MM-DD 形式にしてください。
- 開始時刻・終了時刻は HH:mm 形式にしてください。
- 持ち物は配列にしてください。
- OCRの誤字がありそうな場合も、無理に創作せず、読み取れる範囲で抽出してください。
- 予定名が不明な場合は、文章全体から自然な短いタイトルを作ってください。

OCR結果:
${ocrText}
`;

      const response = await ai.models.generateContent({
        model: GEMINI_MODEL,
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          responseSchema: {
            type: Type.OBJECT,
            properties: {
              title: {
                type: Type.STRING,
                nullable: true,
                description: "予定名。例: 就職説明会、アルバイト面接、ゼミ発表など",
              },
              date: {
                type: Type.STRING,
                nullable: true,
                description: "予定日。YYYY-MM-DD形式",
              },
              startTime: {
                type: Type.STRING,
                nullable: true,
                description: "開始時刻。HH:mm形式",
              },
              endTime: {
                type: Type.STRING,
                nullable: true,
                description: "終了時刻。HH:mm形式",
              },
              location: {
                type: Type.STRING,
                nullable: true,
                description: "集合場所・開催場所",
              },
              items: {
                type: Type.ARRAY,
                items: {
                  type: Type.STRING,
                },
                description: "持ち物の一覧",
              },
              notes: {
                type: Type.STRING,
                nullable: true,
                description: "補足情報、注意事項、集合時間との差分など",
              },
              confidence: {
                type: Type.NUMBER,
                description: "抽出結果への自信。0から1",
              },
            },
            required: [
              "title",
              "date",
              "startTime",
              "endTime",
              "location",
              "items",
              "notes",
              "confidence",
            ],
          },
        },
      });

      const jsonText = response.text;
      const schedule = JSON.parse(jsonText);

      return {
        schedule,
        rawJson: jsonText,
      };
    } catch (error) {
      console.error("GEMINI ERROR:", error);

      throw new HttpsError(
        "internal",
        error.message || "Geminiで予定情報を抽出中にエラーが発生しました。"
      );
    }
  }
);
