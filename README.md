# OCR Calendar App

画像やPDFに書かれた予定情報を読み取り、iPhoneのカレンダーに登録するiOSアプリです。

## 概要

このアプリは、大学のお知らせや説明会案内、締切情報などを含む画像やPDFから、日付・時刻・場所・持ち物を抽出し、確認・修正したうえでiPhone標準カレンダーに登録できます。

## 主な機能

- 写真ライブラリから画像を選択
- カメラで撮影
- ファイルアプリから画像/PDFを選択
- Firebase Storageへアップロード
- Google Cloud Document AIによるOCR
- Vertex AI Geminiによる予定情報の構造化
- 抽出結果の確認・修正
- DatePickerによる日付・時刻修正
- iPhone標準カレンダーへの登録

## 使用技術

- SwiftUI
- EventKit
- Firebase Storage
- Cloud Functions for Firebase
- Google Cloud Document AI
- Vertex AI Gemini
- Node.js

## 工夫した点

- 精度の高いAIでも、多くの文字が煩雑に並んでいる画像などから適切な情報だけを抽出することは困難で、何十回も行ったテストのうち完璧に情報通りの予定が出力された回数は0回でした。そこで、AIの誤認識を前提に、カレンダー登録前に必ず確認・修正画面を挟む設計にし、手入力でタイトルや日付などを変更することができるようにしました。
- 日付の修正手入力を「20XX-XX-XX」のような形式で行っていましたが、スマートフォンの操作での操作を想定し、より直感的かつ入力のしやすいDatePickerで選択できるようにし、入力ミスを減らしました。
- wordなどのドキュメントを読み込ませる際に、毎回ドキュメントのスクリーンショットを撮るような手間をなくすため、画像だけでなくPDFファイルにも対応しました。
- ボタンの数を極力減らし、操作しやすいUIにしました。
## セットアップ注意

このリポジトリには `GoogleService-Info.plist` を含めていません。

利用する場合は、Firebase ConsoleからiOSアプリ用の `GoogleService-Info.plist` を取得し、Xcodeプロジェクトに追加してください。

Cloud Functionsを利用するには、以下のGoogle Cloud APIと権限設定が必要です。

- Firebase Storage
- Cloud Functions
- Cloud Build
- Artifact Registry
- Document AI API
- Vertex AI API

## 現在の状態

MVPとして、画像/PDFの読み取りからカレンダー登録まで動作確認済みです。

## 今後追加したい要素

- ４月７日：入学式
- ５月１１日：体育祭
- ７月１０日：校立記念日（休校）

のような複数の予定が書かれている場合、現状どれか一つの予定のみ抽出するため、複数の予定の同時登録ができません。
→複数の予定を読み取った場合、フォームをその分だけ増やして順番に登録を行える仕様にしたいと考えています。
