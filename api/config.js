// Vercel Serverless Function
// Vercel 프로젝트 설정 > Environment Variables 에 등록한
// SUPABASE_URL / SUPABASE_ANON_KEY 값을 브라우저에 전달만 함.
module.exports = function handler(req, res) {
  res.setHeader("Cache-Control", "no-store");
  res.status(200).json({
    supabaseUrl: process.env.SUPABASE_URL || "",
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || ""
  });
};
